---
layout: post
title: RabbitMQ as a message broker for Ruby and Node.js
---

###The Backstory
I am busy building a SaaS product that has to reliably send large numbers of emails. At [ZappiStore](https://www.zappistore.com/) we use the [Ruby on Rails](http://rubyonrails.org/) stack extensively. I think Rails is an excellent choice for building web applications. Rails makes you super productive and the community support is excellent. Naturally I want to use Rails for the web application layer of the system. There are a couple of different options built into Rails for sending emails.

I don't want a user to have to wait one or two seconds for an SMTP request to finish before they get a response, so sending will have to be done asynchronously. The ActionMailer API in Rails is built for sending emails but ideally I want to pass off the load of sending mails to something that is good at making large amounts of requests and handling them asynchronously. There is support for asynchronous requests in Ruby but it is not as geared towards it as JavaScript is. Also, since Ruby is single-threaded with a global interpreter lock, I want it to do as little processing as possible and rather play to its strengths.

Node.js is built from the ground up with asynchronous operations in mind. Functions are first-class citizens in JavaScript and this makes programming with callbacks easy. Therefore it is a good choice for the creation of a microservice that sends emails. I am using the [Mailgun](https://mailgun.com) API in order to send emails using POST requests.

Since the web application layer is written in Ruby and I have a microservice written in Node.js, these need to pass data between one-another in some way. The communication solution should have the following properties:

- Robust. If a service goes down, the message should be persisted in the queue until it is handled.
- Decoupled. The individual microservices should ideally not have any direct knowledge of each other. Each service should communicate via the message broker.

Enter [RabbitMQ](https://www.rabbitmq.com). Rabbit has been around for a long time and has proven to be a high-performance and reliable message queue. The idea is to use Ruby to push a message onto the queue and then pop the message off of the queue in the Node.js microservice.

###Getting Started with RabbitMQ
For those of us that use OS X, installing RabbitMQ is easiest done with [Homebrew](http://brew.sh/):

```
brew install rabbitmq
```

Once RabbitMQ is installed, start it up as a service with the following command:

```
brew services start rabbitmq
```

###The Ruby Layer
In order to connect to RabbitMQ from Ruby we are going to use the [bunny](https://github.com/ruby-amqp/bunny) gem. Add it to your `Gemfile`:

```
gem 'bunny', '~> 2.3.1'
```

Then run a `bundle install`.

The `bunny` gem gives us a lot of great functionality out of the box like robust connection handling. If the connection to RabbitMQ drops, `bunny` will attempt to reconnect until the connection is restored. The `bunny` gem also gives us an easy API for leveraging RabbitMQ from within our application.

The connection to RabbitMQ should be established at application startup and remain open for the duration of the application's lifetime. To this end we create a MessagingService singleton class:

{% highlight ruby %}
# The messaging service class implements the Singleton pattern
class MessagingService

  # Class variable holding the instance of the class
  @@instance = nil

  def initialize
    # Set the connection object to an instance variable on the object
    @connection = Bunny.new(:host => Settings.rabbitmq.host, :port => Settings.rabbitmq.port)
    @connection.start
  end

  def self.instance
    @@instance ||= MessagingService.new
  end

  def connection
    @connection
  end

end

# Acquire the connection
MessagingService.instance
{% endhighlight %}

By using the Singleton pattern for the `MessageService` class we can ensure that the connection is not closed resulting in us having to reconnect every time we want to send an email. The `EmailQueueService` class uses the connection provided by the `MessageService` class to create a queue for our email pipeline:

{% highlight ruby %}
require_relative 'messaging_service'

# Email queue service also implements the Singleton pattern
class EmailQueueService

  @@instance = nil

  def initialize
    # We can get the connection from the MassagingService
    @connection = MessagingService.instance.connection
    # Create a channel. Since the application is single-threaded, all communication
    # will flow through this single channel
    @channel = @connection.create_channel
    # Create a queue with a name that was defined in the settings.yml file
    @queue = @channel.queue(Settings.queues.email, :durable => true, :auto_delete => false)
  end

  def self.instance
    @@instance ||= EmailQueueService.new
  end

  # Method for adding a message object to the queue
  # The message object is serialized to a JSON string
  def add(msg_object)
    @queue.publish(Oj.dump(msg_object), :persistent => true)
  end

end

# Initialze the object
EmailQueueService.instance
{% endhighlight %}

The `AccountActivationService` class is specific to sending account activation emails when new users sign up:

{% highlight ruby %}
require_relative 'email_queue_service'

# Service specific to sending account activation emails
class AccountActivationService

  @@instance = nil

  def initialize
    # Load the email template into memory
    @text_template = File.open('app/views/email/account_activation_email.text.erb').read
  end

  def self.instance
    @@instance ||= AccountActivationService.new
  end

  def send_email(user)
    # Set template variables
    @user = user
    @settings = Settings

    msg_object = {}
    msg_object['to'] = create_email_address_string(first_name: user.first_name, last_name: user.last_name, email: user.email)
    msg_object['from'] = create_email_address_string(first_name: Settings.app.name, email: Settings.app.emails.activation)
    msg_object['subject'] = "Account Activation"
    # Pass the object binding to the template so that it can access the instance variables
    msg_object['text'] = ERB.new(@text_template).result(binding)
    # Add the message object to the email queue
    EmailQueueService.instance.add(msg_object)
  end

  # Create an email address string of this form: "Timmy Droptables <timmy@tables.com>"
  def create_email_address_string(first_name: nil, last_name: nil, email: nil)
    [first_name, last_name, "<#{email}>"].compact.join(" ")
  end

end

# Initialize the object
AccountActivationService.instance
{% endhighlight %}


###The Node Layer
The `package.json` for the project is as follows:

{% highlight json %}
{
  "name": "email_worker",
  "version": "1.0.0",
  "description": "Email sender microservice for the Mailgun API.",
  "main": "main.js",
  "dependencies": {
    "amqplib": "^0.4.2",
    "lodash": "^4.13.1",
    "mime": "^1.3.4",
    "request": "^2.72.0",
    "winston": "^2.2.0",
    "yamljs": "^0.2.7"
  },
  "devDependencies": {
    "chai": "^3.5.0",
    "mocha": "^2.5.3",
    "mock-require": "^1.3.0"
  },
  "scripts": {
    "start": "node main.js",
    "test": "node node_modules/.bin/mocha"
  },
  "author": "Sebastian Coetzee <mail@sebastiancoetzee.com>"
}
{% endhighlight %}

The `amqplib` library is used to communicate with RabbitMQ, `lodash` as a helper library, `mime` to get the mime types of the email attachments, `request` for sending the HTTP requests, `winston` for logging and `yamljs` to parse the `config.yml` file containing settings.

The bulk of the work is done in the `worker.js` file:

{% highlight javascript %}
var config = require('./config');
var logger = require('./logger');
var mime = require('mime');
var request = require('request');
var _ = require('lodash');
var fs = require('fs');

// Holds the number of active HTTP connections to the Mailgun API.
// I am limiting the max number of open HTTP connections so that
// the worker doesn't get overloaded and so that the work gets spread
// out over multiple workers.
var conns = 0;

module.exports = {

  // Gets a new message from RabbitMQ if one is available
  getMessage: function(conn, channel){
    if (conns >= config.max_http_connections){ return; }
    var that = this;
    channel.get(config.queue, {}, function(err, msg) {
        if (msg) {
          logger.info("Message picked up.", _.omit(msg, ['content']));
          that.send(conn, channel, msg);

          // Add to the count of active connections
          conns++;
          // Only get a new message from RabbitMQ if there are connection slots available
          if (conns < config.max_http_connections){
            // Recursive call
            that.getMessage(conn, channel);
          }
        }
      }
    );
  },

  // Accessor method for the number of active HTTP connections
  getConnections: function(){
    return conns;
  },

  // The request library expects a form data object in this format
  buildFormData: function(msg_obj){
    var formData = _.pick(msg_obj, ['from', 'to', 'cc', 'bcc', 'subject', 'text', 'html']);
    if (msg_obj['file_path']){
      formData['attachment'] = {
        value: fs.createReadStream(msg_obj['file_path']),
        options: {
          filename: msg_obj['file_name'],
          contentType: mime.lookup(msg_obj['file_name'])
        }
      };
    }

    return formData;
  },

  // Send the email using the Mailgun API
  send: function(conn, channel, msg){
    var msg_obj = JSON.parse(msg.content.toString());
    var formData = this.buildFormData(msg_obj);

    var auth = {
      'user': 'api',
      'pass': config.api_key
    }

    request.post(
      {
        url: config.api_base_url + "/messages",
        formData: formData,
        auth: auth
      },
      function(err, response, body){
        // Return a possible connection to the pool
        conns--;
        if (err) {
          logger.error("An error occured while posting to the Mailgun API: ", err);

          // Acknowledge that the handling of the message failed.
          return channel.nack(msg, false, false);
        }
        logger.info("Successfully sent mail.", _.omit(msg, ['content']));

        // Acknowledge that the handling of the message succeeded.
        channel.ack(msg);
      }
    )
  }

};
{% endhighlight %}

The worker is the started using the `main.js` file:

{% highlight javascript %}
var config = require('./config');
var logger = require('./logger');
var worker = require('./worker');

require('amqplib/callback_api')
  .connect(
    'amqp://' + config.rabbitmq_host + ':' + config.rabbitmq_port,
    function(err, conn) {
      if (err != null){
        logger.error("Could not create connection.", err);
        process.exit(1);
      }
      conn.createChannel(
        function(err, channel) {
          if (err != null){
            logger.error("Could not create channel.", err);
            process.exit(1);
          }
          channel.assertQueue(config.queue);
          setInterval(
            function(){
              logger.info("Poll. HTTP connections: " + worker.getConnections(), null);
              worker.getMessage(conn, channel);
            },
            config.polling_rate
          );
        }
      );
    }
  );
{% endhighlight %}

###Putting it all together
In order to send email accross the queue, the following code is executed from the Rails `UsersController`:

{% highlight ruby %}
class UsersController < ApplicationController

  def create
    return unless validate_required_params(:email, :password, :password_confirmation)
    user = User.new(params.permit(:email, :password, :password_confirmation))
    if user.save

      # Send the user the activation email
      AccountActivationService.instance.send_email(user)

      render_json(200, StatusMessage::SUCCESS, nil, "User successfully registered. Please check your email for activation instructions.")
    else
      render_json(401, StatusMessage::ERROR, nil, "User registration failed.")
    end
  end

end
{% endhighlight %}

###Summary
[Node.js](https://nodejs.org) provides first-class support for asynchronous execution of HTTP requests. This makes it a great technology to use for sending emails via the [Mailgun](https://www.mailgun.com/) API. [Ruby on Rails](http://rubyonrails.org/) is great for building web applications. We want to leverage the best features of these two technologies together and we implemented [RabbitMQ](https://www.rabbitmq.com) to enable robust communication between the Ruby and the JavaScript layers.
