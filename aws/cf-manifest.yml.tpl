---
name: CloudFoundry
director_uuid: BOSH_UUID

releases:
- {name: cf, version: 215}

networks:
- name: private
  type: manual
  subnets:
  - range: 10.0.0.0/24
    gateway: 10.0.0.1
    dns: [10.0.0.2]
    reserved: ["10.0.0.2 - 10.0.0.9"]
    static: ["10.0.0.10 - 10.0.0.100"]
    cloud_properties: {subnet: ${aws_subnet_id}}

resource_pools:
- name: small_z1
  network: private
  stemcell:
    name: bosh-aws-xen-hvm-ubuntu-trusty-go_agent
    version: 3063
  cloud_properties:
    instance_type: t2.small
    availability_zone: ${aws_availability_zone}
    ephemeral_disk: {size: 25_000, type: gp2}

compilation:
  workers: 3
  network: private
  reuse_compilation_vms: true
  cloud_properties:
    instance_type: c3.large
    availability_zone: ${aws_availability_zone}
    ephemeral_disk: {size: 25_000, type: gp2}

update:
  canaries: 1
  max_in_flight: 1
  serial: false
  canary_watch_time: 30000-600000
  update_watch_time: 5000-600000

jobs:
- name: nats_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: nats, release: cf}
  - {name: nats_stream_forwarder, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.10]

- name: etcd_z1
  instances: 1
  resource_pool: small_z1
  persistent_disk: 102400
  templates:
  - {name: etcd, release: cf}
  - {name: etcd_metrics_server, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.11]
  properties:
    etcd_metrics_server:
      nats:
        machines: [10.0.0.10]
        password: PASSWORD
        username: nats

- name: postgres_z1
  instances: 1
  persistent_disk: 1024
  resource_pool: small_z1
  templates:
  - {name: postgres, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.14]
  update:
    serial: true

- name: api_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: cloud_controller_ng, release: cf}
  - {name: cloud_controller_worker, release: cf}
  - {name: cloud_controller_clock, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.15]

- name: hm9000_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: hm9000, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.16]

- name: doppler_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: doppler, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.17]
  properties:
    doppler: {zone: z1}
    doppler_endpoint:
      shared_secret: PASSWORD

- name: loggregator_trafficcontroller_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: loggregator_trafficcontroller, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.18]
  properties:
    traffic_controller: {zone: z1}

- name: uaa_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: uaa, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.19]
  properties:
    login:
      catalina_opts: -Xmx768m -XX:MaxPermSize=256m
    uaa:
      admin:
        client_secret: PASSWORD
      batch:
        password: PASSWORD
        username: batch_user
      cc:
        client_secret: PASSWORD
      scim:
        userids_enabled: true
        users:
        - admin|PASSWORD|scim.write,scim.read,openid,cloud_controller.admin,doppler.firehose
    uaadb:
      address: 10.0.0.14
      databases:
      - {name: uaadb, tag: uaa}
      db_scheme: postgresql
      port: 5524
      roles:
      - {name: uaaadmin, password: PASSWORD, tag: admin}

- name: router_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: gorouter, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.20]
  properties:
    dropsonde: {enabled: true}

- name: runner_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: dea_next, release: cf}
  - {name: dea_logging_agent, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.21]
  properties:
    dea_next: {zone: z1}

- name: stats_z1
  instances: 1
  resource_pool: small_z1
  templates:
  - {name: collector, release: cf}
  - {name: metron_agent, release: cf}
  networks:
  - name: private
    static_ips: [10.0.0.22]
  properties:
    collector: {deployment_name: CF}

properties:
  networks: {apps: private}
  app_domains: [10.0.0.20.xip.io]
  cc:
    allow_app_ssh_access: false
    bulk_api_password: PASSWORD
    db_encryption_key: PASSWORD
    default_running_security_groups: [public_networks, dns]
    default_staging_security_groups: [public_networks, dns]
    install_buildpacks:
    - {name: java_buildpack, package: buildpack_java}
    - {name: ruby_buildpack, package: buildpack_ruby}
    - {name: nodejs_buildpack, package: buildpack_nodejs}
    - {name: go_buildpack, package: buildpack_go}
    - {name: python_buildpack, package: buildpack_python}
    - {name: php_buildpack, package: buildpack_php}
    - {name: staticfile_buildpack, package: buildpack_staticfile}
    - {name: binary_buildpack, package: buildpack_binary}
    internal_api_password: PASSWORD
    quota_definitions:
      default:
        memory_limit: 102400
        non_basic_services_allowed: true
        total_routes: 1000
        total_services: -1
    security_group_definitions:
    - name: public_networks
      rules:
      - {destination: 0.0.0.0-9.255.255.255, protocol: all}
      - {destination: 11.0.0.0-169.253.255.255, protocol: all}
      - {destination: 169.255.0.0-172.15.255.255, protocol: all}
      - {destination: 172.32.0.0-192.167.255.255, protocol: all}
      - {destination: 192.169.0.0-255.255.255.255, protocol: all}
    - name: dns
      rules:
      - {destination: 0.0.0.0/0, ports: "53", protocol: tcp}
      - {destination: 0.0.0.0/0, ports: "53", protocol: udp}
    srv_api_uri: http://api.10.0.0.20.xip.io
    staging_upload_password: PASSWORD
    staging_upload_user: staging_upload_user
  ccdb:
    address: 10.0.0.14
    databases:
    - {name: ccdb, tag: cc}
    db_scheme: postgres
    port: 5524
    roles:
    - {name: ccadmin, password: PASSWORD, tag: admin}
  databases:
    databases:
    - {name: ccdb, tag: cc, citext: true}
    - {name: uaadb, tag: uaa, citext: true}
    port: 5524
    roles:
    - {name: ccadmin, password: PASSWORD, tag: admin}
    - {name: uaaadmin, password: PASSWORD, tag: admin}
  dea_next:
    advertise_interval_in_seconds: 5
    heartbeat_interval_in_seconds: 10
    memory_mb: 33996
  description: Cloud Foundry sponsored by Pivotal
  domain: 10.0.0.20.xip.io
  etcd:
    machines: [10.0.0.11]
  hm9000:
    url: http://hm9000.10.0.0.20.xip.io
  logger_endpoint:
    port: 4443
  loggregator_endpoint:
    shared_secret: PASSWORD
  login:
    protocol: http
  metron_agent:
    zone: z1
    deployment: minimal-aws
  metron_endpoint:
    shared_secret: PASSWORD
  nats:
    machines: [10.0.0.10]
    password: PASSWORD
    port: 4222
    user: nats
  ssl:
    skip_cert_verify: true
  system_domain: 10.0.0.20.xip.io
  system_domain_organization: default_organization
  uaa:
    clients:
      cc-service-dashboards:
        authorities: clients.read,clients.write,clients.admin
        authorized-grant-types: client_credentials
        scope: openid,cloud_controller_service_permissions.read
        secret: PASSWORD
      cloud_controller_username_lookup:
        authorities: scim.userids
        authorized-grant-types: client_credentials
        secret: PASSWORD
      gorouter:
        authorities: clients.read,clients.write,clients.admin,route.admin,route.advertise
        authorized-grant-types: client_credentials,refresh_token
        scope: openid,cloud_controller_service_permissions.read
        secret: PASSWORD
      doppler:
        authorities: uaa.resource
        secret: PASSWORD
      login:
        authorities: oauth.login,scim.write,clients.read,notifications.write,critical_notifications.write,emails.write,scim.userids,password.write
        authorized-grant-types: authorization_code,client_credentials,refresh_token
        redirect-uri: http://login.10.0.0.20.xip.io
        scope: openid,oauth.approvals
        secret: PASSWORD
      servicesmgmt:
        authorities: uaa.resource,oauth.service,clients.read,clients.write,clients.secret
        authorized-grant-types: authorization_code,client_credentials,password,implicit
        autoapprove: true
        redirect-uri: http://servicesmgmt.10.0.0.20.xip.io/auth/cloudfoundry/callback
        scope: openid,cloud_controller.read,cloud_controller.write
        secret: PASSWORD
    jwt:
      signing_key: |
        -----BEGIN RSA PRIVATE KEY-----
        MIICXAIBAAKBgQDHFr+KICms+tuT1OXJwhCUmR2dKVy7psa8xzElSyzqx7oJyfJ1
        JZyOzToj9T5SfTIq396agbHJWVfYphNahvZ/7uMXqHxf+ZH9BL1gk9Y6kCnbM5R6
        0gfwjyW1/dQPjOzn9N394zd2FJoFHwdq9Qs0wBugspULZVNRxq7veq/fzwIDAQAB
        AoGBAJ8dRTQFhIllbHx4GLbpTQsWXJ6w4hZvskJKCLM/o8R4n+0W45pQ1xEiYKdA
        Z/DRcnjltylRImBD8XuLL8iYOQSZXNMb1h3g5/UGbUXLmCgQLOUUlnYt34QOQm+0
        KvUqfMSFBbKMsYBAoQmNdTHBaz3dZa8ON9hh/f5TT8u0OWNRAkEA5opzsIXv+52J
        duc1VGyX3SwlxiE2dStW8wZqGiuLH142n6MKnkLU4ctNLiclw6BZePXFZYIK+AkE
        xQ+k16je5QJBAN0TIKMPWIbbHVr5rkdUqOyezlFFWYOwnMmw/BKa1d3zp54VP/P8
        +5aQ2d4sMoKEOfdWH7UqMe3FszfYFvSu5KMCQFMYeFaaEEP7Jn8rGzfQ5HQd44ek
        lQJqmq6CE2BXbY/i34FuvPcKU70HEEygY6Y9d8J3o6zQ0K9SYNu+pcXt4lkCQA3h
        jJQQe5uEGJTExqed7jllQ0khFJzLMx0K6tj0NeeIzAaGCQz13oo2sCdeGRHO4aDh
        HH6Qlq/6UOV5wP8+GAcCQFgRCcB+hrje8hfEEefHcFpyKH+5g1Eu1k0mLrxK2zd+
        4SlotYRHgPCEubokb2S1zfZDWIXW3HmggnGgM949TlY=
        -----END RSA PRIVATE KEY-----
      verification_key: |
        -----BEGIN PUBLIC KEY-----
        MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDHFr+KICms+tuT1OXJwhCUmR2d
        KVy7psa8xzElSyzqx7oJyfJ1JZyOzToj9T5SfTIq396agbHJWVfYphNahvZ/7uMX
        qHxf+ZH9BL1gk9Y6kCnbM5R60gfwjyW1/dQPjOzn9N394zd2FJoFHwdq9Qs0wBug
        spULZVNRxq7veq/fzwIDAQAB
        -----END PUBLIC KEY-----
    no_ssl: true
    url: http://uaa.10.0.0.20.xip.io
