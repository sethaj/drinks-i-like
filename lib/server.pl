#!/usr/bin/env perl
use strict;
use warnings;

package DB::Drink;
use base qw(DBIx::Class);
__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('drink');
__PACKAGE__->add_columns(
  id => {
    data_type => 'integer',
    is_auto_increment => 1
  },
  title => {
    data_type => 'text',
  },
  description => {
    data_type => 'text'
  }
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([ qw/title/ ]);


package DB;
use base qw(DBIx::Class::Schema);
__PACKAGE__->load_classes(qw(Drink));


package main;
use Mojolicious::Lite;
use File::Basename;
use lib dirname (__FILE__);
use JSON;
use Mojo::Log;
my $log = Mojo::Log->new;
use Data::Dumper;
use Try::Tiny;

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub build_database {
  my $schema = get_schema();
  my $dbh = $schema->storage->dbh;
  my $sth = $dbh->prepare("select name from sqlite_master WHERE type='table' AND name='drink'");
  $sth->execute();
  my $name = $sth->fetchrow();
  if (!$name) {
    # build sqlite and add test data if needed
    $schema->deploy();
    $schema->resultset('Drink')->create({
      title => 'milk',
      description => '"Milk is for babies. When you grow up you have to drink beer." - Arnold Schwarzenegger'
    });
  }
}

my $schema;
sub get_schema {
  return $schema || DB->connect("dbi:SQLite:dbname=drinks-i-like.db");
};

sub handle_resultset {
  my $rs = shift;
  my $ref;
  while (my $r = $rs->next) {
    push @$ref, handle_result($r);
  }
  return $ref;;
}

sub handle_result {
  my $r = shift;
  return {
    id => $r->id,
    title => $r->title,
    description => $r->description,
  }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Documentation browser under "/perldoc" (this plugin requires Perl 5.10)
#plugin 'pod_renderer';
plugin 'PODRenderer';

# Set public/ directory path to project root
app->static->paths->[0] = app->home->rel_dir('../public');
#app->static->root( app->home->rel_dir('../public') );

# build schema if needed
build_database();

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Routes
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

# Home page
get '/'               => \&handle_home;

# Add a drink
post '/api/drink'     => \&handle_post_drink;

# Get all drinks
get '/api/drink'      => \&handle_get_drinks;

# Get drink
get '/api/drink/:id'  => \&handle_get_drink;

# Update a drink
put '/api/drink/:id'  => \&handle_put_drink;

# Delete a drink
del '/api/drink/:id'   => \&handle_delete_drink;
del '/api/drink'       => \&handle_delete_drink;

app->start;

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Controller
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
sub handle_home {
  my $self = shift;

  $self->render('index');
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
sub handle_get_drink {
  my $self = shift;
  
  my $id = $self->param( 'id' );

  # Return error if missing parameter (400)
  if ( !defined($id) ) {
    return self->render(json => [], status => 400);
  }
  else {
    my $drink = get_drink_by_id( $id );
    return $self->render(json => handle_result( $drink ), status => 200);
  }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
sub handle_get_drinks {
  my $self = shift;
  my $drinks = get_drinks();
  return $self->render(json => handle_resultset( $drinks ) );
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
sub handle_post_drink {

  my $self = shift;

  my $title       = $self->param( 'title' );
  my $description = $self->param( 'description' );

  # Use JSON content if parameter not defined
  if ( defined( $self->req->content ) ) {

    my $drink;

    eval {
     $drink = decode_json( $self->req->content->asset->{'content'} );
    };

    if ( defined( $drink ) ) {

      $title = $drink->{'title'} if !defined($title) && defined($drink->{'title'});

      $description = $drink->{'description'} if !defined($description) && defined($drink->{'description'});

    }

  }

  # Return error if missing parameter (400)
  if ( !defined($title) || !defined( $description ) ) {
    return $self->render(json => [], status => 400 );
  }

  # Return error if not add drink (conflict, 409)
  if ( ! add_drink( $title, $description ) ) {
    return $self->render(json => [], status => 409);
  }

  # Return 201 & id
  my $drink = get_drink_by_title($title);
  return $self->render(json => handle_result( $drink ), status => 201 );
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
sub handle_put_drink {
  my $self = shift;
  my $id          = $self->param( 'id' );
  my $drink       = decode_json( $self->req->content->asset->{'content'} );

  # Return error if missing parameter (400)
  if ( !defined($id) || !defined( $drink ) || !defined($drink->{'title'}) || !defined($drink->{'description'}) ) {
    return $self->render(json => [], status => 400 );
  }

  $drink = update_drink( $id, $drink->{'title'}, $drink->{'description'} );

  if ( ! defined( $drink ) ) {
    return $self->render(json => [], status => 400 );
  }

  return $self->render(json => handle_result( $drink ), status => 200 );

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
sub handle_delete_drink {
  my $self = shift;
  my $id  = $self->param( 'id' );

  # Use JSON content if parameter not defined
  if ( !defined( $id ) && defined( $self->req->content ) ) {

    our $drink;

    eval {
     $drink = decode_json( $self->req->content->asset->{'content'} );
    };

    if ( defined( $drink ) ) {
      $id = $drink->{'id'} if defined($drink->{'id'});
    }

  }

  # Return error if missing parameter (400)
  if ( ! defined($id) ) {
    return $self->render(json => [], status => 400 );
  }

  my $drink = delete_drink($id);

  if ( ! defined( $drink ) ) {
    return $self->render(json => [], status => 400 );
  }

  return $self->render(json => handle_result( $drink ), status => 200 );
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub add_drink {
  my ( $title, $description ) = @_;

  my $schema = get_schema();

  try {
    return $schema->resultset('Drink')->create({
      title => $title,
      description => $description,
    });
  }
  catch {
    $log->warn($_);
    return;
  }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub delete_drink {
  my ( $id ) = @_;

  my $drink = get_drink_by_id($id);

  return undef if ! defined( $drink );

  try {
    $drink->delete(); 
    return $drink
  }
  catch {
    $log->warn($_);
    return;
  }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub update_drink {
  my ( $id, $title, $description ) = @_;

  my $drink = get_drink_by_id($id);

  return undef if ! defined( $drink );
  
  try {
    $drink->update({
      title => $title,
      description => $description,
    });
    return $drink;
  } 
  catch {
    $log->warn($_);
    return;
  }
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub get_drinks {
  my $schema = get_schema();

  try {
    return $schema->resultset('Drink');
  }
  catch {
    $log->warn($_);
    return;
  }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub get_drink_by_title {
  my( $title ) = @_;

  my $schema = get_schema();

  try {
    return $schema->resultset('Drink')->search({
      title => $title
    })->single;
  }
  catch {
    $log->warn($_);
    return;
  }
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub get_drink_by_id {
  my( $id ) = @_;

  my $schema = get_schema();
  
  try {
    return $schema->resultset('Drink')->search({
      id => $id
    })->single;
  }
  catch {
    $log->warn($_);
    return;
  }
}


__DATA__

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Inline templates
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
@@ index.html.ep
% layout 'default';
% title 'Drinks I Like';

  <div class="table-responsive">
    <table class="table table-striped table-bordered table-hover">
      <tr>
        <th class="title">Name</th>
        <th class="description">Description</th>
        <th class="actions">&nbsp;</th>
      </tr>
        <tr ng-repeat="(id, drink) in drinkList">
          <td>
            <input id="{{ 'drink-title-' + id }}" class="form-control" ng-blur="editDrink(drink)" ng-model="drink.title"></input>
          </td>
          <td>
            <input id="{{ 'drink-description-' + id }}" class="form-control" ng-blur="editDrink(drink)" ng-model="drink.description" type="text"></input>
          </td>
          <td>
            <a href="#" ng-click="removeDrink(drink.id)">x</a>
          </td>
        </tr>
        <tr>
          <td colspan="3">
          </td>
        </tr>
        <tr>
          <form name="drinkForm" ng-submit="addDrink()" class="form-inline">
            <td>
              <input class="form-control" type="text" name="title" id="add-title" ng-model="newDrink.title" placeholder="New Title" />
            </td>
            <td>
              <input class="form-control" type="text" name="description" id="add-description" ng-model="newDrink.description" placeholder="New Description" />
            </td>
            <td>
              <button type="submit" class="btn btn-primary">Add Drink</button>
            </td>
          </form>
        </tr>
    </table>
  </div>
 
@@ layouts/default.html.ep
<!doctype html>
<html>
  <head>
    <title><%= title %></title>
    <link rel="stylesheet" type="text/css" media="screen" href="/bower_components/bootstrap/dist/css/bootstrap.min.css" />
    <link rel="stylesheet" type="text/css" media="screen" href="/css/animate.min.css" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  </head>
  <body ng-app="DrinkApp" ng-controller="DrinkController">
    <div class="container-fluid" role="main">
      <div class="row-fluid">
        <div class="well pagination-centered">
          <h1><%= title %></h1>
          <%= content %>
        </div>
      <div>
    </div>
    <script src="/bower_components/angular/angular.min.js"></script>
    <script src="/bower_components/jquery/dist/jquery.min.js"></script>
    <script src="/bower_components/bootstrap/dist/js/bootstrap.min.js"></script>
    <script src="/js/app.js"></script>
  </body>
</html>
