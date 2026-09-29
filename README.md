# NodeGoat

**Experimental use only.** This entire project is for experimentation. Do not run any scripts or configuration in this repository against a production environment.

Offical Fork - [https://github.com/OWASP/NodeGoat.git](https://github.com/OWASP/NodeGoat.git)

Being lightweight, fast, and scalable, Node.js is becoming a widely adopted platform for developing web applications. This project provides an environment to learn how OWASP Top 10 security risks apply to web applications developed using Node.js and how to effectively address them.

## Getting Started

OWASP Top 10 for Node.js web applications:

### Know it!

This application bundled a tutorial page that explains the OWASP Top 10 vulnerabilities and how to fix them.

Once the application is running, you can access the tutorial page at [http://localhost:4000/tutorial](http://localhost:4000/tutorial) (or the port you have configured).

### Do it!

##### Default user accounts

The database comes pre-populated with these user accounts created as part of the seed data -

- Admin Account - u:`admin` p:`Admin_123`
- User Accounts (u:`user1` p:`User1_123`), (u:`user2` p:`User2_123`)
- New users can also be added using the sign-up page.

## How to Set Up Your Copy of NodeGoat

### OPTION 1 - Run NodeGoat on your machine

1. Install [Node.js](http://nodejs.org/) - NodeGoat requires Node v8 or above

2. Clone the github repository:

   ```
   git clone https://github.com/rkfrog/node-goat.git
   ```

3. Go to the directory:

   ```
   cd NodeGoat
   ```

4. Install node packages:

   ```
   npm install
   ```

5. Set up MongoDB. You can either install MongoDB locally or create a remote instance:

   - Using local MongoDB:

     1. Install [MongoDB Community Server](https://docs.mongodb.com/manual/administration/install-community/)
     2. Start [mongod](http://docs.mongodb.org/manual/reference/program/mongod/#bin.mongod)

   - Using remote MongoDB instance:
     1. [Deploy a MongoDB Atlas free tier cluster](https://docs.atlas.mongodb.com/tutorial/deploy-free-tier-cluster/) (M0 Sandbox)
     2. [Enable network access](https://docs.atlas.mongodb.com/security/add-ip-address-to-list/) to the cluster from your current IP address
     3. [Add a database user](https://docs.atlas.mongodb.com/tutorial/create-mongodb-user-for-cluster/) to the cluster
     4. Set the `MONGODB_URI` environment variable to the connection string of your cluster, which can be viewed in the cluster's
        [connect dialog](https://docs.atlas.mongodb.com/tutorial/connect-to-your-cluster/#connect-to-your-atlas-cluster). Select "Connect your application",
        set the driver to "Node.js" and the version to "2.2.12 or later". This will give a connection string in the form:
        ```
        mongodb://<username>:<password>@<cluster>/<dbname>?ssl=true&replicaSet=<rsname>&authSource=admin&retryWrites=true&w=majority
        ```
        The `<username>` and `<password>` fields need filling in with the details of the database user added earlier. The `<dbname>` field sets the name of the
        database nodegoat will use in the cluster (eg "nodegoat"). The other fields will already be filled in with the correct details for your cluster.

6. Populate MongoDB with the seed data required for the app:

   ```
   npm run db:seed
   ```

   By default this will use the "development" configuration, but the desired config can be passed as an argument if required.

7. Start the server. You can run the server using node or nodemon:
   - Start the server with node. This starts the NodeGoat application at [http://localhost:4000/](http://localhost:4000/):
     ```
     npm start
     ```
   - Start the server with nodemon, which will automatically restart the application when you make any changes. This starts the NodeGoat application at [http://localhost:5000/](http://localhost:5000/):
     ```
     npm run dev
     ```

#### Customizing the Default Application Configuration

By default the application will be hosted on port 4000 and will connect to a MongoDB instance at localhost:27017. To change this set the environment variables `PORT` and `MONGODB_URI`.

Other settings can be changed by updating the [config file](https://github.com/OWASP/NodeGoat/blob/master/config/env/all.js).

### OPTION 2 - Run NodeGoat on Docker

The repo includes the Dockerfile and docker-compose.yml necessary to set up the app and db instance, then connect them together.

1. Install [docker](https://docs.docker.com/installation/) and [docker compose](https://docs.docker.com/compose/install/)

2. Clone the github repository:

   ```
   git clone https://github.com/rkfrog/node-goat.git
   ```

3. Go to the directory:

   ```
   cd NodeGoat
   ```

4. Build the images:

   ```
   docker-compose build
   ```

5. Run the app, this starts the NodeGoat application at http://localhost:4000/:
   ```
   docker-compose up
   ```

## Report bugs, Feedback, Comments

- Open a new [issue](https://github.com/OWASP/NodeGoat/issues) or contact team by joining chat at [Slack](https://owasp.slack.com/messages/project-nodegoat/) or [![Join the chat at https://gitter.im/OWASP/NodeGoat](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/OWASP/NodeGoat?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Contributing

Please Follow [the contributing guide](CONTRIBUTING.md)

## Code Of Conduct (CoC)

This project is bound by a [Code of Conduct](CODE_OF_CONDUCT.md).

## Contributors

Here are the amazing [contributors](https://github.com/OWASP/NodeGoat/graphs/contributors) to the NodeGoat project.

## Supports

- Thanks to JetBrains for providing licenses to fantastic [WebStorm IDE](https://www.jetbrains.com/webstorm/) to build this project.

## License

Code licensed under the [Apache License v2.0.](http://www.apache.org/licenses/LICENSE-2.0)


## JFrog Bootstrap

[Bootstrap instructions on the JFrog platform resources (repos, projects, lifecycle, stages, and application)](./docs/jfrog-bootstrap.md)