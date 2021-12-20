# First run
## Initiate replica set
```js
rs.initiate({
  _id: "main",
  members: [
    { _id: 1, host: "mongo-primary.service.consul:27017", priority: 10 },
    { _id: 2, host: "mongo-secondary.service.consul:27017", priority: 1 },
    { _id: 3, host: "mongo-arbiter.service.consul:27017", arbiterOnly:true }
  ]
});

rs.status()
```

## Create superuser and vault user
```js
use admin

db.createUser(
  {
    user: 'root',
    pwd: 'password',
    roles: [ { role: "root", db: "admin"} ]
  }
);

db.createUser(
  {
    user: "vault",
    pwd: "password",
    roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
  }
);
```
