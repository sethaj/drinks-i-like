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
      return $http.put('/api/drink/' + drink.id, drink)
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

  $scope.getDrinks = function() {
    drinkService.getDrinks().then(function(result) {
      $scope.drinkList = result.data;
    });
  };

  $scope.addDrink = function() {
    drinkService.createDrink($scope.newDrink).then(function(result) {
      $scope.drinkList.push(result.data);
      $scope.newDrink = '';
      $scope.drinkForm.$setPristine();
    });
  };

  $scope.removeDrink = function(id) {
    drinkService.destroyDrink(id).then(function(result) {
      $scope.getDrinks();
    });
  };

  $scope.editDrink = function(drink) {
    drinkService.updateDrink(drink).then(function(result) {
      $scope.getDrinks();
    });
  };

  $scope.getDrinks();

}]);

