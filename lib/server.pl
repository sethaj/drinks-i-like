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
  return DB->connect("dbi:SQLite:dbname=drinks-i-like.db");
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
<aside>
  <form name="" id="new-drink">
    <h1>New Drink</h1>
    <label for="title">Name</label>
    <input type="text" name="title" id="add-title" />
    <label for="description">Description</label>
    <textarea name="description" id="add-description"></textarea>
    <input type="submit" id="add-drink" value="Add drink" />
  </form>
</aside>
<% my $rows = [
    { title => 'Test #1', description => 'Testing a description #1' },
    { title => 'Test #2', description => 'Testing a description #2' },
    { title => 'Test #3', description => 'Testing a description #3' },  
  ]; %>

<script id="drinks-template" type="template/jquery">
  <tr>
    <td><input class="title" id="${title}" value="${title}" />
        <input type="hidden" class="id" value="${id}" /></td>
    <td><textarea class="description" >${description}</textarea></td>
    <td class="actions"><a href="#" class="remove-drink">x</a></td>
  </tr>
</script>

<section>
  <table id="drinks">
    <tr>
      <th class="title">Name</th>
      <th class="description">Description</th>
      <th class="actions">&nbsp;</th>
    </tr>

    %# This dummy data will be removed by backbone
    <% for my $row ( @$rows ) { %>
      <tr>
        <td><input class="title" name="" value="<%= $row->{'title'} %>" /></td>
        <td><input class="description" name="" value="<%= $row->{'description'} %>" /></td>
        <td><a href="#">x</a></td>
      </tr>
    <% } %>
  </table>
</section>
 
@@ layouts/default.html.ep
<!doctype html>
<html>
  <head>
    <title><%= title %></title>
    <script src="/js/jquery.js"></script>
    <script src="/js/json2.js"></script>
    <script src="/js/underscore.js"></script>
    <script src="/js/backbone.js"></script>
    <script src="/js/modernizr.custom.76020.js"></script>
    <script src="/js/jquery.tmpl.min.js"></script>
    <script src="/js/library.js"></script>
    <link rel="stylesheet" type="text/css" media="screen" href="/css/bootstrap.min.css"/>
    <link rel="stylesheet" type="text/css" media="screen" href="/css/screen.css"/>
  </head>
  <body>
    <header>
      <h1><%= title %></h1>
    </header>
    <div role="main">
      <%= content %>
    </div>
  </body>
</html>
