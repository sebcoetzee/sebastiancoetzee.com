---
layout: post
title: 'Configuration Languages: A Balance of Constraints'
---

Configuration is a topic that is often debated among software teams. It's one of those issues that every engineer has an (often strong) opinion about and there isn't a definitive right or wrong answer. Even something as basic as the method for passing config to an application can be tough to agree on.

Some prefer command-line arguments, others environment variables, some swear by passing config as a JSON file to the application, and believe it or not there's even one guy in my office who prefers XML. To illustrate the point, check out Microsoft's documentation on [ASP.NET Core configuration](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-7.0). It's a "mere" 77-minute read according to Microsoft.

Almost every organisation should be running multiple different instances of the same application, with different configurations. There could be any number of reasons for this. Here are some real-world examples:

- Different environments: dev, test, stage, and/or prod.
- Data importers might have multiple instances, each consuming from a different Kafka partition in the same Kafka cluster.
- A trading system might implement the same strategy, but across different exchanges and/or instruments.
- Some critical applications might have failover systems that use backup versions of some dependencies such as replicas of databases etc.

These separate instances will often have slight differences in their configuration, with many commonalities. Regardless of the vector used to deliver the config to the application, engineers will have to define the config for each of these instances of the application. It is essential for a developer platform to have a tool in its toolchain that allows engineers to define these commonalities in the config between different instances, while still allowing specialisations for specific instances.

Config management is an important layer of the developer platform. The most natural way to define config is to use some sort of language or markup format. Before discussing the implementation details of such a config management language it might be good to define the ideal attributes. Ideally, engineers should be able to define config in a language that is:

- **Easy to understand**
- **Expressive**
- **Constrained**
- **Statically checked** (as much as possible)
- **Versioned**
- **Audited**
- **Integrated** with the deployment infrastructure

I'll start by presenting the view of [Matt Rickard](https://matt-rickard.com/) who has an excellent blog that you should definitely check out. In a blog post titled **Every Sufficiently Advanced Configuration Language is Wrong** Matt [argues](https://matt-rickard.com/advanced-configuration-languages-are-wrong) that:

> For basic configuration, YAML or JSON is usually good enough. It falls apart when you try to do more:
>
> - Template it with a templating engine
> - Use esoteric language features to reuse code (anchors and aliases)
> - Patch or modify it with something like JSONPatch
> - Type-check or schema validate

I agree with Matt's assertion that for basic config we needn't look further than JSON or YAML. I also agree that, when done wrong, templating and esoteric language features will be more of a bane than a boon.

Matt then goes on to mention that these are anti-patterns, and that more advanced configuration languages have been developed ([Jsonnet](https://jsonnet.org/), [CUE](https://cuelang.org/), [Dhall](https://dhall-lang.org/)) to solve these problems. On the trend of configuration languages becoming ever more advanced Matt says:

> The logical extreme is becoming more evident – advanced configuration in general-purpose programming languages. You can see this in the emergence of Typescript for Infrastructure-as-Code. For the most basic (and human 0x777) configuration needs, there will always be simple formats – YAML, JSON, INI, etc.).
>
> For everything else, general-purpose languages will win out.

The steel man version of Matt's argument boils down to: engineers are smart, and we should be giving engineers the most powerful and flexible tools possible. General-purpose languages like Python or TypeScript would allow engineers to use all the typical software development techniques to write maintainable, testable config.

Unfortunately, in the absence of strict discipline, guidelines, and/or adherence to patterns the power of a general-purpose language could quickly lead to config that is unmaintainable. My objection isn't so much with using a general-purpose language as it is with not having any constraints on how config is written.

To help back up my point, I will refer to a great [talk](https://blog.janestreet.com/caveat-configurator-how-to-replace-configs-with-code-and-why-you-might-not-want-to/) by Dominick LoBraico of Jane Street: **Caveat Configurator: how to replace configs with code, and why you might not want to**.

In this talk, Dominick articulates the journey Jane Street took from having static configs in config files to the other extreme of having config written in OCaml and distributed along with the code of the applications themselves. Dominick mentions various trade-offs they had to make with regards to:

- **Expressiveness**
- **Versioning**
- **Safety**

Jane Street ended up finding a happy medium with what he calls a "config generation" step. I assume this config generation step involves evaluating all the configuration code and producing some sort of output (JSON or other) that can be versioned separately from the application code and the config source code.

As an engineer in a Platform Engineering team, I can say that I have been on much the same journey as Dominick. Over the last year I have been setting the vision and direction for the company's internal developer platform. In the process I've had to redesign a lot of the implementation of the config management and deployment infrastructure.

The configuration management system is YAML-based. There are three different types of config YAML files:

- **Libraries**: can be shared between multiple applications or inherited from.
- **Applications**: map one-to-one with applications that are deployed within the company's infrastructure. In object-oriented terms, these would be classes.
- **Deployments**: contain the definitions of all the instances of applications. In object-oriented terms, these would be instantiations of the classes defined in the application config YAMLs.

Libraries and Applications can declare:

- **Variable declarations**: type, data type, default definition.
- **Plugin definitions**: often some external systems need to be configured in order for the application to function properly (e.g. httpd config, systemd units, or crontab entries).
- **Commands**: command line string that gets run on start, or custom commands.
- **Hooks**: custom commands that are executed at certain points in the application lifecycle.

Deployments can define:

- **Instance**: the name of a specific deployment. Must be unique.
- **Variable definition overrides**: allows specific definitions per instance.
- **Environment**: dev, test, stage, prod.

Certain clearly defined fields (variables, commands, hooks, plugin definitions) can use Jinja templates that can reference variables that are defined within the same scope or imported scopes. This allows engineers to share common config between related applications/instances. Engineers also have access to the power of Jinja's templating engine with [Native types](https://jinja.palletsprojects.com/en/3.0.x/nativetypes/) which allows returning Python types as the result of rendering Jinja templates. Jinja implements a subset of Python along with useful primitives for string manipulation such as filters.

All config YAMLs are stored and versioned in a central git repository. This versions the source of config and enforces the regular software development best practices of pull requests and code reviews.

As a simple, somewhat contrived example we could have one application that consumes some data feed of trades and publishes it to a Kafka topic. We could then also have a consumer that reads from the same Kafka topic. Ignoring the complexities around Kafka partitioning, we could define the config for these fictional applications as follows:

The Kafka configuration can be shared between instances. We place this in its own library config.

```yaml
# kafka.library.yml

variable_declarations:
  bootstrap_servers:
    type: static
    data_type: string

instances:
  dev:
    bootstrap_servers: kafkadev3,kafkadev4,kafkadev5
  prod:
    bootstrap_servers: kafkaprod11,kafkaprod12,kafkaprod13
```

Notice how we've defined a set of Kafka bootstrap server hostnames per environment.

The producer should have its own application config:

```yaml
# producer.application.yml

import:
  - name: kafka
    instance: '{% raw %}{{ environment }}{% endraw %}'
  - name: resource

variable_declarations:
  telemetry_port:
    type: runtime
    data_type: integer
    default: '{% raw %}{{ resource.tcp_port() }}{% endraw %}'
  trading_instrument:
    type: static
    data_type: string

commands:
  start: >
    bin/producer
      --bootstrap-servers {% raw %}{{ kafka.bootstrap_servers }}{% endraw %}
      --kafka-topic trades-{% raw %}{{ trading_instrument }}{% endraw %}
      --telemetry-port {% raw %}{{ telemetry_port }}{% endraw %}
      --trading-instrument {% raw %}{{ trading_instrument }}{% endraw %}
```

The `telemetry_port` is a `runtime` variable. This means that the value of the variable is not known until the application commands are run. In this specific case, we are allocating a telemetry port for the application dynamically from a pool of reserved ports. Care is taken to ensure that runtime variables cannot be referenced from a static context. Static variables should be resolvable at config generation. The goal is to make as many of the variables static as possible. Static variables offer advantages over runtime variables: they can be statically checked at config generation. Config generation is triggered by a webhook on the version control system. This allows developers to catch classes of errors at code review as opposed to the first time an application is started up in production.

The `trading_instrument` is a declared variable that has no default definition. This means that it will have to be overridden in the deployment config.

The consumer should also have its own application config:

```yaml
# consumer.application.yml

import:
  - name: kafka
    instance: '{% raw %}{{ environment }}{% endraw %}'

variables:
  trading_instrument:
    type: static
    data_type: string

commands:
  start: >
    bin/consumer
      --bootstrap-servers {% raw %}{{ kafka.bootstrap_servers }}{% endraw %}
      --kafka-topic trades-{% raw %}{{ trading_instrument }}{% endraw %}
      --trading-instrument {% raw %}{{ trading_instrument }}{% endraw %}
```

The consumer can import the same Kafka config as the producer. This means we have no duplicate definition of the Kafka `bootstrap_servers`.

The deployment configs define the instances of the producer and consumer:

```yaml
# producer.deployment.yml

application: producer
deployments:
  - instance: default
    environment: dev
    overrides:
      trading_instrument: DUMMY
  
  - instance: SPX
    environment: prod
    overrides:
      trading_instrument: SPX

  - instance: DAX
    environment: prod
    overrides:
      trading_instrument: DAX
```

```yaml
# consumer.deployment.yml

application: consumer
deployments:
  - instance: default
    environment: dev
    overrides:
      trading_instrument: DUMMY
  
  - instance: SPX
    environment: prod
    overrides:
        trading_instrument: SPX

  - instance: DAX
    environment: prod
    overrides:
        trading_instrument: DAX
```

These deployment configs for our fictional applications would be committed to the central git repository containing all the config YAML files. Once merged to master, the config generation CI step would produce new versions of JSON configurations for these applications in a standardised format that is understood by the deployment system. This JSON config is versioned and the engineer is able to deploy the new version of the config for that application or revert to an older version of the config by simply selecting which version of the config to deploy from a dropdown.

At this point it might be useful to check back with the ideal attributes we defined for our configuration management tooling:

**Easy to understand**: I'm biased, but I think the DSL is relatively easy to understand and use. There are only a handful of concepts, the rules are clearly defined, and it's unlikely that engineers will write unmaintainable config in such a simple DSL.

**Expressive**: This DSL is not as expressive as a general-purpose programming language, but it still leaves a decent amount of the design decisions of how to structure the config up to the engineer. Variable definitions can be referenced from other variable definitions, namespaces can be imported into other namespaces, and the developer has access to the Jinja templating engine which implements a subset of Python.

**Constrained**: The DSL tries to be the happy medium between the extremes of a general-purpose language with no framework and the other extreme of a rigid structure that needs development effort at the framework-layer to support new types of configuration. The constraints that are enforced help reduce complexity and reduce the chances of config becoming unmaintainable.

**Statically checked**: The static parts of the config are evaluated at config generation time. This provides a safety net to engineers that allows them to find issues like syntax errors, references to undefined variables, runtime variables referenced from a static context, circular dependencies, and invalid YAML before they even merge their PRs.

**Versioned**: Both the config source and the outputs of config generation are versioned.

**Audited**: The deployment infrastructure keeps track of which versions of the config are deployed to which instances. Changes are easily diffable via the deployer's UI, so engineers are always aware of what changes they are deploying.

**Integrated**: Engineers will happily use tools if it can save them manual work and time. By having the config management fully integrated with the rest of the developer platform we can automate steps that developers need to take to comply with the software development lifecycle policy. This includes automatically generating change control requests from the config changes which can be submitted for review, automating the deployment process, allowing easy rollbacks, integrating with alerting and monitoring systems etc.

## Conclusion

The key to good configuration management is to find the right balance between expressiveness and constraints. Engineers should be given a language that is powerful enough to adequately model the config of their application. However, by adding some sensible constraints to a configuration language, we can make configuration more maintainable, versioned, audited, integrated, and easier to understand.
