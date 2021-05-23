## Docker Compose

### Prerequisites:

[Docker Desktop](https://hub.docker.com/editions/community/docker-ce-desktop-windows)

[Visual Studio Code](https://code.visualstudio.com/)


### Loose Agenda:

Play with docker-compose
Orchestrate multiple container images


### Step by Step

#### Single image example

In a playground directory, create a new file named ```docker-compose.yml``` and enter the following text

```
services:
  redis:
    image: redis
```

In a terminal instance opened to today's playground directory run `docker-compose up --d`

Once that finishes, run `docker ps -a` to see that a container was started.

Connect to our container with `docker exec -it docker-compose_redis_1 redis-cli`.

You should now be in the container's redis-cli process. 

Run the following commands to see that redis is functioning as expected:
```
KEYS *
SET day non-zero
KEYS *
GET day
```

Run `docker-compose down` in the terminal instance to shut down and clean up the containers.

#### Single Dockerfile example

In the playground directory, create a new file named `Dockerfile` and enter the following text
```
FROM redis
```

In the playground directory, create a new file named `docker-compose-dockerfile.yml` and enter the following text
```
  redis:
    build: .
```

Run `docker compose -f docker-compose-dockerfile.yml up -d` to start containers per the docker-compose definition. Again, run `docker ps -a` to see that a container was started.

Connect to our container with `docker exec -it docker-compose_redis_1 redis-cli`.

You should now be in the container's redis-cli process. 

Run the following commands again to see that redis is functioning as expected:
```
KEYS *
SET day non-zero
KEYS *
GET day
```

In the terminal instance let's clean up with ` docker-compose -f docker-compose-dockerfile.yml down` 

#### Volume mounting with Postgres and PgAdmin

Now let's play with Postgres and Docker-Compose.

Create a sql directory within which create an `init.sql` file with the following contents.

``` sql/init.sql
CREATE DATABASE nonzero;
```

Alongside init.sql in the `sql` directory, create a `pgadmin_servers.json` file. This file will be used to tell PGAdmin about the Postgres instance we will be creating.

``` sql/pgadmin_servers.json
{
    "Servers":{
        "1": {
            "Name": "Docker-Compose",
            "Group": "Local Servers",
            "Port": 5432,
            "Username": "docker",
            "Host": "postgres",
            "SSLMode": "prefer",
            "MaintenanceDB": "postgres"
        }
    }
}
```

Additionally create a `docker-compose-postgres.yml` with the following content

``` docker-compose-postgres.yml
version: '3'
services:
    postgres:
        image: postgres:11
        restart: always
        ports:
        - 5432:5432
        environment:
        - POSTGRES_USER=docker
        - POSTGRES_PASSWORD=docker
        volumes:
        - ./sql/init.sql:/docker-entrypoint-initdb.d/init.sql

    pgadmin:
        image: dpage/pgadmin4
        restart: always
        ports:
        - 5431:80    
        depends_on: 
            - postgres
        environment:
            PGADMIN_DEFAULT_EMAIL: $${PGADMIN_DEFAULT_EMAIL:-user@domain.org}
            PGADMIN_DEFAULT_PASSWORD: $${PGADMIN_DEFAULT_PASSWORD:-docker}
            PGADMIN_CONFIG_SERVER_MODE: 'False'
            PGADMIN_SERVER_JSON_FILE: '/pgadmin4/servers.json'
        volumes:
        - ./sql/pgadmin_servers.json:/pgadmin4/servers.json
        
```

Run `docker compose -f docker-compose-postgres.yml up` to start containers per the docker-compose definition. 

Navigate to [http://localhost:5431/browser/](http://localhost:5431/browser/) and browser into Local Servers > Docker-Compose > Databases to see that our `nonzero` database was created.

Run `docker compose -f docker-compose-postgres.yml down` to shut down and clean up our containers. 

#### Image coordination with Flyway against Postgres

Let's add Flyway to our Postgres Docker-Compose definition.

Create a new file in the sql directory named `V1.0.0__Table.sql` with the following contents

``` V1.0.0__Table.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE nonzerotable (
   id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
   name TEXT NOT NULL,
   age INT NOT NULL,
   address CHAR(50)
);
```

We'll modify our `docker-compose-postgres.yml` to the following

``` docker-compose-postgres.yml
version: '3'
services:
    flyway:
      image: flyway/flyway:7.7.1
      environment:
           - FLYWAY_USER=docker
           - FLYWAY_PASSWORD=docker
      command: migrate 
                -url=jdbc:postgresql://postgres:5432/nonzero 
                -locations=filesystem:/flyway/sql 
                -connectRetries=60
                -mixed=true
      volumes:
        - ./sql:/flyway/sql
      depends_on:
        - postgres
        
    postgres:
        image: postgres:11
        restart: always
        ports:
        - 5432:5432
        environment:
        - POSTGRES_USER=docker
        - POSTGRES_PASSWORD=docker
        volumes:
        - ./sql/init.sql:/docker-entrypoint-initdb.d/init.sql

    pgadmin:
        image: dpage/pgadmin4
        restart: always
        ports:
        - 5431:80    
        depends_on: 
            - postgres
        environment:
            PGADMIN_DEFAULT_EMAIL: $${PGADMIN_DEFAULT_EMAIL:-user@domain.org}
            PGADMIN_DEFAULT_PASSWORD: $${PGADMIN_DEFAULT_PASSWORD:-docker}
            PGADMIN_CONFIG_SERVER_MODE: 'False'
            PGADMIN_SERVER_JSON_FILE: '/pgadmin4/servers.json'
        volumes:
        - ./sql/pgadmin_servers.json:/pgadmin4/servers.json
```


Run `docker compose -f docker-compose-postgres.yml up` to start containers per the docker-compose definition. 

Navigate to [http://localhost:5431/browser/](http://localhost:5431/browser/) and browser into Local Servers > Docker-Compose > Databases to see that our `nonzero` database now contains a nonzerotable.

Run `docker compose -f docker-compose-postgres.yml down` to shut down and clean up our containers. 

#### Health Checking

Note the retries occuring in the Flyway container defined in the previous section. We eventually reach the desired state due to the connectRetries argument in the Flyway container. We can also do this with health checks.

``` docker-compose-postgres.yml
version: '3'
services:
    flyway:
      image: flyway/flyway:7.7.1
      depends_on:
        postgres:
          condition: service_healthy
      environment:
           - FLYWAY_USER=docker
           - FLYWAY_PASSWORD=docker
      command: migrate 
                -url=jdbc:postgresql://postgres:5432/nonzero 
                -locations=filesystem:/flyway/sql 
                -connectRetries=60
                -mixed=true
      volumes:
        - ./sql:/flyway/sql
        
    postgres:
        image: postgres:11
        restart: always
        ports:
        - 5432:5432
        environment:
        - POSTGRES_USER=docker
        - POSTGRES_PASSWORD=docker
        volumes:
        - ./sql/init.sql:/docker-entrypoint-initdb.d/init.sql
        healthcheck:
            test: ["CMD-SHELL", "pg_isready -U docker"]
            interval: 5s
            timeout: 5s
            retries: 5

    pgadmin:
        image: dpage/pgadmin4
        restart: always
        ports:
        - 5431:80    
        depends_on: 
            - postgres
        environment:
            PGADMIN_DEFAULT_EMAIL: $${PGADMIN_DEFAULT_EMAIL:-user@domain.org}
            PGADMIN_DEFAULT_PASSWORD: $${PGADMIN_DEFAULT_PASSWORD:-docker}
            PGADMIN_CONFIG_SERVER_MODE: 'False'
            PGADMIN_SERVER_JSON_FILE: '/pgadmin4/servers.json'
        volumes:
        - ./sql/pgadmin_servers.json:/pgadmin4/servers.json

```

Running `docker compose -f docker-compose-postgres.yml up` will now show the flyway container waiting for the postgres container to report healthy before executing. 


Congratulations on a non-zero day!

### Documentation
- [Docker Compose](https://docs.docker.com/compose/)
- [Dockerfile](https://docs.docker.com/engine/reference/builder/)
- [PgAdmin Docker Hub](https://hub.docker.com/r/dpage/pgadmin4/)
- [Flyway Docker Hub](https://hub.docker.com/r/flyway/flyway)
- [Postgres Docker Hub](https://hub.docker.com/_/postgres)
- [PgAdmin Container Deployment](https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html)
- [Flyway Docker Compose](https://github.com/flyway/flyway-docker#docker-compose)
