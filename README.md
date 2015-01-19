About
=====

This is a fork of the awesome _drinks_i_like_(https://github.com/bryanesmith/drinks-i-like) with the following changes:

* MySQL replaced with SQLite
* DBIx::Class ORM added
* Backbone replaced with Angular
* Twitter Bootstrap added
* Carton(https://github.com/perl-carton/carton) added to manage perl dependancies
* Bower(http://bower.io/) added to manage javascript dependancies

Install
=======

* Install a newish perl with plenv(https://github.com/tokuhirom/plenv)
* Install cpanminus with `plenv install-cpanm`
* Install carton with `cpanm carton`
* Install perl dependancies `carton install`
* Install bower (and nodejs)
* Install javascript dependancies `bower install`


Run
===

1. Run bin/server:

  `carton exec bin/server` 
  [Wed May 16 10:18:52 2012] [info] Server listening (http://*:3000)
  Server available at http://127.0.0.1:3000.

You can modify the PORT variable in this script to select a different port.

2. In your browser, visit: http://127.0.0.1:3000


Restful Interface
=================

For each of the following, if you visit the site's home page (http://127.0.0.1/ by default), you can run the specified jQuery command from the JavaScript console in your browser to test the functionality.

For more information on building a RESTful interface, see: [http://goo.gl/YjyDM]

1. (Create) To add a drink: POST /api/drink/

```
    jQuery.post("/api/drink", {
      "title": "Espresso",
      "description": '"It is inhumane, in my opinion, to force people who have a genuine medical need for coffee to wait in line behind people who apparently view it as some kind of recreational activity." - Dave Barry',
    }, function (data, textStatus, jqXHR) {
        console.log("Response: "); 
        console.dir(data); 
        console.log(textStatus); 
        console.dir(jqXHR);
    });
```
2. (Read)   To get a drink: GET /api/drink/:id
```
    jQuery.get("/api/drink/1", function(data, textStatus, jqXHR) {
            console.log("Response: ");
      console.dir(data);
      console.log(textStatus);
      console.dir(jqXHR);
    });
```
  Or to get all drinks: GET /api/drink/
```
    jQuery.get("/api/drink/", function (data, textStatus, jqXHR) {
            console.log("Response: ");
        console.dir(data);
        console.log(textStatus);
        console.dir(jqXHR);
    });
```
3. (Update) To update a drink: PUT /api/drink/:id
```
    jQuery.ajax({
        url: "/api/drink/1",
        type: "PUT",
        data: {
          "description": '"Baby mammals drink milk, and you sir, are a baby mammal." - Mark Rippetoe'
        },
        success: function (data, textStatus, jqXHR) {
            console.log("Response: ");
            console.dir(data);
            console.log(textStatus);
            console.dir(jqXHR);
        }
    });
```
4. (Delete) To delete a drink: DELETE /api/drink/:id
```
    jQuery.ajax({
        url: "/api/products/1", 
        type: "DELETE",
        success: function (data, textStatus, jqXHR) {
            console.log("Response: ");
            console.dir(data); 
            console.log(textStatus); 
            console.dir(jqXHR); 
        }
    });
```
Useful Resources
================

* Develop a RESTful API Using Node.js With Express and Mongoose [http://goo.gl/G1u4j]

* Designing a RESTful Web Application [http://goo.gl/YjyDM]

