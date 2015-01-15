drinkApp = angular.module('DrinkApp', []);

drinkApp.config(function($logProvider) {
  $logProvider.debugEnabled(false);
});

drinkApp.run(function($rootScope, $log) {
  $rootScope.$log = $log;
});


drinkApp.service('drinkService', ['$http', function($http) {

  return {
    getDrinks: function() {
      return $http.get('/api/drink')
    },
    getDrink: function(id) {
      return $http.get('/api/drink/' + id)
    },
    updateDrink: function(drink) {
      return $http.put('/api/drink/' + id, drink)
    },
    createDrink: function(drink) {
      return $http.post('/api/drink', drink)
    },
    destroyDrink: function(id) {
      return $http.delete('/api/drink/' + id)
    }
  }

}]);


drinkApp.controller('DrinkController', ['$scope', 'drinkService', function($scope, drinkService) {

  // list current drinks
  var refresh = function() {
    drinkService.getDrinks().then(function(data) {
      $scope.drinkList = data.data;
    });
  };
  refresh();

  // add a new drink
  $scope.addDrink = function() {
    drinkService.createDrink($scope.newDrink);
    refresh();
  }; 

  // remove a drink
  $scope.removeDrink = function(id) {
    drinkService.destroyDrink(id);
    refresh();
  };


}]);

