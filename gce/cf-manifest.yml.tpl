---
name: ${deployment_name}
director_uuid: BOSH_UUID

releases:
 - name: cf
   version: ${cf_release}

compilation:
  workers: 4
  network: default
  reuse_compilation_vms: true
  cloud_properties:
    machine_type: n1-standard-2
    preemptible: true

update:
  canaries: 0
  canary_watch_time: 30000-600000
  update_watch_time: 30000-600000
  max_in_flight: 32
  serial: false

networks:
  - name: default
    type: dynamic
    cloud_properties:
      network_name: ${network_name}
      ephemeral_external_ip: true
      tags:
        - bosh
        - ${deployment_name}

  - name: static
    type: vip

resource_pools:
  - name: common
    network: default
    stemcell:
      name: bosh-google-kvm-ubuntu-trusty-go_agent
      version: latest
    cloud_properties:
      machine_type: n1-standard-4
      root_disk_size_gb: 40
      root_disk_type: pd-standard

  - name: large
    network: default
    stemcell:
      name: bosh-google-kvm-ubuntu-trusty-go_agent
      version: latest
    cloud_properties:
      machine_type:  n1-highmem-8
      root_disk_size_gb: 40
      root_disk_type: pd-standard

disk_pools:
  - name: data
    disk_size: 40_960
    cloud_properties:
      type: pd-ssd

  - name: core
    disk_size: 10_024
    cloud_properties:
      type: pd-ssd

jobs:
  - name: haproxy
    templates:
      - name: haproxy
      - name: consul_agent
      - name: metron_agent
    instances: 1
    resource_pool: large
    networks:
      - name: default
        default: [dns, gateway]
      - name: static
        static_ips:
          - ${static_ip}

  - name: data
    templates:
      - name: debian_nfs_server
      - name: postgres
      - name: metron_agent
    instances: 1
    resource_pool: common
    persistent_disk_pool: data
    networks:
      - name: default
        default: [dns, gateway]

  - name: core
    templates:
      - name: nats
      - name: nats_stream_forwarder
      - name: etcd
      - name: etcd_metrics_server
      - name: hm9000
      - name: uaa
      - name: login
      - name: metron_agent
    instances: 1
    resource_pool: common
    persistent_disk_pool: core
    networks:
      - name: default
        default: [dns, gateway]

  - name: api
    templates:
      - name: gorouter
      - name: routing-api
      - name: cloud_controller_ng
      - name: cloud_controller_clock
      - name: cloud_controller_worker
      - name: consul_agent
      - name: doppler
      - name: loggregator_trafficcontroller
      - name: syslog_drain_binder
      - name: metron_agent
      - name: nfs_mounter
    instances: 1
    resource_pool: common
    networks:
      - name: default
        default: [dns, gateway]

  - name: runner
    templates:
      - name: dea_next
      - name: dea_logging_agent
      - name: metron_agent
    instances: 3
    resource_pool: large
    networks:
      - name: default
        default: [dns, gateway]
    update:
      max_in_flight: 1

properties:
  networks:
    apps: default

  ca_truster:
    certificates: []

  ssl:
    skip_cert_verify: true

  syslog_aggregator: {}

  domain: ${root_domain}
  system_domain: ${root_domain}
  system_domain_organization: admin
  app_domains:
    - ${root_domain}

  request_timeout_in_seconds: 300

  ha_proxy:
    disable_http: false
    ssl_pem: |
      -----BEGIN CERTIFICATE-----
      MIIBrTCCARYCCQC8Nv/VzAW5gzANBgkqhkiG9w0BAQsFADAbMQ0wCwYDVQQKDARC
      b3NoMQowCAYDVQQDDAEqMB4XDTE0MDcyNDA0MjkzNloXDTI0MDcyMTA0MjkzNlow
      GzENMAsGA1UECgwEQm9zaDEKMAgGA1UEAwwBKjCBnzANBgkqhkiG9w0BAQEFAAOB
      jQAwgYkCgYEAusGqZW2nSyqSI5RY8Hm8270XfYEuR3kPVYuwwAftEi7BSaR+4fpb
      a9kXaJwcPMIecQOsPTByoqyXfseUx1yZVBEnq/7ZjYj1ipfGa99XfQEjCzXaS3Je
      NkdwhJf3IZf7XQMhSZMs7NmvZ6aD91st83NCr316fdDoKvRRi66YlOcCAwEAATAN
      BgkqhkiG9w0BAQsFAAOBgQCc6HCnAY3PdykXNXLyrnRk31tuHCrwSKSGH+tf24v8
      DO9wUuuja+jGYou5lE+lzRs8KBYR97ENb0hNC0oYrU3XWinWJAdM2Dp3/lWQJF9T
      9yQKNnctjW6U7YbCqkbkZXesZglSjtTnyiVlD59shmDNZZCQnbG7CLkrnlQGuM4n
      zg==
      -----END CERTIFICATE-----
      -----BEGIN CERTIFICATE REQUEST-----
      MIIBWjCBxAIBADAbMQ0wCwYDVQQKDARCb3NoMQowCAYDVQQDDAEqMIGfMA0GCSqG
      SIb3DQEBAQUAA4GNADCBiQKBgQC6waplbadLKpIjlFjwebzbvRd9gS5HeQ9Vi7DA
      B+0SLsFJpH7h+ltr2RdonBw8wh5xA6w9MHKirJd+x5THXJlUESer/tmNiPWKl8Zr
      31d9ASMLNdpLcl42R3CEl/chl/tdAyFJkyzs2a9npoP3Wy3zc0KvfXp90Ogq9FGL
      rpiU5wIDAQABoAAwDQYJKoZIhvcNAQELBQADgYEAVpFm7oKKgQsuK1RUxoJ25XO2
      aS9GpengE57N0LH1dKxyHF7g+fPer6YAwpNE7bZNjyPRkng33OJ7N67nvYtFs6eN
      CFBf8okWpmFgJ6gC5zNxYQRm1RU7+RUpM2ceMT1g14SmA5ffS48rYaSx2raKphYA
      KI1neJFzwM3gQfrwI+s=
      -----END CERTIFICATE REQUEST-----
      -----BEGIN PRIVATE KEY-----
      MIICeAIBADANBgkqhkiG9w0BAQEFAASCAmIwggJeAgEAAoGBALrBqmVtp0sqkiOU
      WPB5vNu9F32BLkd5D1WLsMAH7RIuwUmkfuH6W2vZF2icHDzCHnEDrD0wcqKsl37H
      lMdcmVQRJ6v+2Y2I9YqXxmvfV30BIws12ktyXjZHcISX9yGX+10DIUmTLOzZr2em
      g/dbLfNzQq99en3Q6Cr0UYuumJTnAgMBAAECgYEAjQFwcEiMiXpJAMgfJuIjsB1j
      QQVqNdi3tTVVbIgPfS0ED2A91M08fX9Z50gHIfDHHzlQsJqF00FQ2Q5DzQqjUMS+
      EJvVQsen71B8LNkKB+8GlJjTN+QoW0UAWtvK6gRYB4VIe+5LrWlioQWHucYH8UzB
      veyzthWQBPfxDkYrvdECQQDsR0T/oo0kN3GHcwRe4p4oVMUncu9pci8IRZf7gSKN
      8db+LVTSm7jrhUOmSmCL//A2VnoNpPriFaP573dHH9kLAkEAylg56itY8Kn9AAAk
      1BlFprO0Odecz8Cf8ZNzzpAvnN/AqRSF04PTUCRavJonGirW6tU+qgybMMO3uVHf
      9/W1FQJAQn/Ihp4sVS4ZkMKpTz8+viEln/W0NhxB6nUT0mBE5mhTVxRRFDlpsTe/
      k3TJeX2eEN0D2wU86xamIPjpvCXVgwJBAJ+CQ01tFHTLnEz20BF/Rp/uQ+HhLZW8
      pJlcgstQcKg63vaq3gBqiBdCQWEyKCcBpGCE8Bw/Sct8TgXCHEutHy0CQQCv14lC
      nM7h6y+I9r3cqZRBDMfWpvAl25doctNWY0McmudIT9FHIBtvayRnBqa9Z554Bk6S
      f+4pffb9Gl/e6Fxh
      -----END PRIVATE KEY-----

  nfs_server:
    address: 0.data.default.${deployment_name}.microbosh
    allow_from_entries:
      - "*.${deployment_name}.microbosh"
    idmapd_domain: "localdomain"

  databases: &databases
    db_scheme: postgres
    address: 0.data.default.${deployment_name}.microbosh
    port: 5524
    roles:
      - tag: admin
        name: ccadmin
        password: ${common_password}
      - tag: admin
        name: uaaadmin
        password: ${common_password}
      - tag: admin
        name: consoleadmin
        password: ${common_password}
    databases:
      - tag: cc
        name: ccdb
        citext: true
      - tag: uaa
        name: uaadb
        citext: true
      - tag: console
        name: consoledb
        citext: true

  ccdb: &ccdb
    db_scheme: postgres
    address: 0.data.default.${deployment_name}.microbosh
    port: 5524
    roles:
      - tag: admin
        name: ccadmin
        password: ${common_password}
    databases:
      - tag: cc
        name: ccdb
        citext: true

  uaadb:
    db_scheme: postgresql
    address: 0.data.default.${deployment_name}.microbosh
    port: 5524
    roles:
      - tag: admin
        name: uaaadmin
        password: ${common_password}
    databases:
      - tag: uaa
        name: uaadb
        citext: true

  nats:
    user: nats
    password: ${common_password}
    address: 0.core.default.${deployment_name}.microbosh
    port: 4222
    machines:
      - 0.core.default.${deployment_name}.microbosh

  etcd:
    machines:
      - 0.core.default.${deployment_name}.microbosh

  etcd_metrics_server:
    nats:
      machines:
        - 0.core.default.${deployment_name}.microbosh
      username: nats
      password: ${common_password}

  hm9000:
    url: ${protocol}://hm9000.${root_domain}

  cc: &cc
    external_host: api
    srv_api_uri: ${protocol}://api.${root_domain}
    jobs:
      global:
        timeout_in_seconds: 14400
      app_bits_packer:
        timeout_in_seconds: null
      app_events_cleanup:
        timeout_in_seconds: null
      app_usage_events_cleanup:
        timeout_in_seconds: null
      blobstore_delete:
        timeout_in_seconds: null
      blobstore_upload:
        timeout_in_seconds: null
      droplet_deletion:
        timeout_in_seconds: null
      droplet_upload:
        timeout_in_seconds: null
      model_deletion:
        timeout_in_seconds: null
      generic:
        number_of_workers: null
    app_events:
      cutoff_age_in_days: 31
    app_usage_events:
      cutoff_age_in_days: 31
    audit_events:
      cutoff_age_in_days: 31
    billing_event_writing_enabled: true
    users_can_select_backend: true
    diego_docker: false
    default_to_diego_backend: false
    allow_app_ssh_access: true
    default_app_memory: 1024
    default_app_disk_in_mb: 1024
    maximum_app_disk_in_mb: 2048
    client_max_body_size: 1536M
    default_health_check_timeout: 60
    maximum_health_check_timeout: 180

    bulk_api_password: ${common_password}
    internal_api_user: internal_user
    internal_api_password: ${common_password}
    logging_level: debug2
    db_logging_level: debug2
    staging_upload_user: upload
    staging_upload_password: ${common_password}
    db_encryption_key: ${common_password}
    disable_custom_buildpacks: false
    broker_client_timeout_seconds: 70
    broker_client_default_async_poll_interval_seconds: 60
    broker_client_max_async_poll_duration_minutes: 10080
    resource_pool:
      resource_directory_key: cloudfoundry-resources
      fog_connection:
        provider: Local
        local_root: /var/vcap/nfs/shared
    packages:
      app_package_directory_key: cloudfoundry-packages
      fog_connection:
        provider: Local
        local_root: /var/vcap/nfs/shared
      max_package_size: 1073741824
    droplets:
      droplet_directory_key: cloudfoundry-droplets
      fog_connection:
        provider: Local
        local_root: /var/vcap/nfs/shared
    development_mode: false
    buildpacks:
      buildpack_directory_key: cloudfoundry-buildpacks
      fog_connection:
        provider: Local
        local_root: /var/vcap/nfs/shared
    newrelic:
      license_key: null
      environment_name: ${deployment_name}
      developer_mode: false
      monitor_mode: false
      capture_params: false
      transaction_tracer:
        enabled: true
        record_sql: obfuscated
    install_buildpacks:
      - name: java_buildpack
        package: buildpack_java
      - name: ruby_buildpack
        package: buildpack_ruby
      - name: nodejs_buildpack
        package: buildpack_nodejs
      - name: go_buildpack
        package: buildpack_go
      - name: python_buildpack
        package: buildpack_python
      - name: php_buildpack
        package: buildpack_php
      - name: staticfile_buildpack
        package: buildpack_staticfile
      - name: binary_buildpack
        package: buildpack_binary
    quota_definitions:
      default:
        memory_limit: 10240
        total_services: 100
        non_basic_services_allowed: true
        total_routes: 1000
        trial_db_allowed: true
      runaway:
        memory_limit: 102400
        total_services: -1
        total_routes: 1000
        non_basic_services_allowed: true
    security_group_definitions:
      - name: public_networks
        rules:
          - protocol: all
            destination: 0.0.0.0-9.255.255.255
          - protocol: all
            destination: 11.0.0.0-169.253.255.255
          - protocol: all
            destination: 169.255.0.0-172.15.255.255
          - protocol: all
            destination: 172.32.0.0-192.167.255.255
          - protocol: all
            destination: 192.169.0.0-255.255.255.25
      - name: internal_network
        rules:
          - protocol: all
            destination: 10.0.0.0-10.255.255.255
      - name: dns
        rules:
          - destination: 0.0.0.0/0
            ports: '53'
            protocol: tcp
          - destination: 0.0.0.0/0
            ports: '53'
            protocol: udp
    default_running_security_groups:
      - public_networks
      - internal_network
      - dns
    default_staging_security_groups:
      - public_networks
      - internal_network
      - dns
    allowed_cors_domains: []
    thresholds:
      api:
        alert_if_above_mb: null
        restart_if_consistently_above_mb: null
        restart_if_above_mb: null
      worker:
        alert_if_above_mb: null
        restart_if_consistently_above_mb: null
        restart_if_above_mb: null
    external_protocol: ${protocol}

  dea: &dea
    disk_mb: 102400
    disk_overcommit_factor: 2
    memory_mb: 51200
    memory_overcommit_factor: 3
    staging_disk_inode_limit: 200000
    instance_disk_inode_limit: 200000
    kernel_network_tuning_enabled: true
    directory_server_protocol: ${protocol}
    evacuation_bail_out_time_in_seconds: 600
    logging_level: debug
    staging_disk_limit_mb: 6144
    staging_memory_limit_mb: 1024
    mtu: 1454
    deny_networks:
      - 169.254.0.0/16 # Metadata endpoint
    advertise_interval_in_seconds: 5
    default_health_check_timeout: 60
    heartbeat_interval_in_seconds: 10
    rlimit_core: 0
  dea_next: *dea
  disk_quota_enabled: true

  dea_logging_agent:
    status:
      user: admin
      password: ${common_password}

  consul:
    agent:
      services:
        - "cloud_controller_ng"

  dropsonde:
    enabled: true

  doppler:
    zone: 'zone'
    outgoing_port: 8083

  doppler_endpoint:
    shared_secret: ${common_password}

  logger_endpoint:
    use_ssl: false #<%= protocol == 'https' %>
    port: 80

  loggregator_endpoint:
    shared_secret: ${common_password}
    host: 0.api.default.${deployment_name}.microbosh

  loggregator:
    incoming_port: 3456
    outgoing_port: 8081
    doppler_port: 8083
    zone: 'zone'
    servers:
      zone:
        -  0.api.default.${deployment_name}.microbosh

  traffic_controller:
    zone: 'zone'
    incoming_port: 3457
    outgoing_port: 8082

  metron_endpoint:
    shared_secret: ${common_password}

  metron_agent:
    zone: 'zone'
    deployment: ${deployment_name}

  router:
    enable_ssl: false
    requested_route_registration_interval_in_seconds: 20
    secure_cookies: false
    endpoint_timeout: 60
    status:
      port: 8080
      user: gorouter
      password: ${common_password}
    servers:
      z1:
        - 0.api.default.${deployment_name}.microbosh
      z2: []

  login:
    enabled: true
    protocol: ${protocol}
    port: 8081
    catalina_opts: -Xmx768m -XX:MaxPermSize=256m
    brand: oss
    links:
      home: ${protocol}://console.${root_domain}
      passwd: ${protocol}://console.${root_domain}/password_resets/new
      signup: ${protocol}://console.${root_domain}/register

  uaa:
    url: ${protocol}://uaa.${root_domain}
    no_ssl: true #<%= protocol == 'http'%>
    catalina_opts: -Xmx768m -XX:MaxPermSize=256m
    cc:
      client_secret: ${common_password}
    admin:
      client_secret: ${common_password}
    batch:
      username: batch
      password: ${common_password}
    clients:
      cf:
        override: true
        authorized-grant-types: implicit,password,refresh_token
        authorities: uaa.none
        scope: cloud_controller.read,cloud_controller.write,openid,password.write,cloud_controller.admin,scim.read,scim.write,doppler.firehose
        access-token-validity: 7200
        refresh-token-validity: 1209600
      admin:
        secret: ${common_password}
        authorized-grant-types: client_credentials
        authorities: clients.read,clients.write,clients.secret,password.write,scim.write,scim.read,uaa.admin
      login:
        id: login
        override: true
        autoapprove: true
        scope: openid,oauth.approvals
        authorities: oauth.login,scim.write,clients.read,notifications.write,critical_notifications.write,emails.write,scim.userids,password.write
        secret: ${common_password}
        authorized-grant-types: authorization_code,client_credentials,refresh_token
        redirect-uri: ${protocol}://login.${root_domain}
      portal:
        override: true
        scope: openid,cloud_controller.read,cloud_controller.write,password.write,console.admin,console.support
        authorities: scim.write,scim.read,cloud_controller.read,cloud_controller.write,password.write,uaa.admin,uaa.resource,cloud_controller.admin,billing.admin
        secret: ${common_password}
        authorized-grant-types: authorization_code,client_credentials
        access-token-validity: 1209600
        refresh-token-validity: 1209600
        redirect-uri: ${protocol}://console.${root_domain}/oauth/callback
      cc_service_broker_client:
        id: cc_service_broker_client
        override: true
        autoapprove: true
        secret: ${common_password}
        authorized-grant-types: client_credentials
        scope: cloud_controller.write,openid,cloud_controller.read,cloud_controller_service_permissions.read
        authorities: clients.read,clients.write,clients.admin
        access-token-validity: 1209600
        refresh-token-validity: 1209600
      cloud_controller_username_lookup:
        authorities: scim.userids
        authorized-grant-types: client_credentials
        secret: ${common_password}
      developer_console:
        secret: ${common_password}
      doppler:
        authorities: uaa.resource
        override: true
        secret: ${common_password}
      notifications:
        authorities: cloud_controller.admin,scim.read
        authorized-grant-types: ${common_password}
        secret: ${common_password}
      gorouter:
        authorities: clients.read,clients.write,clients.admin,route.admin,route.advertise
        authorized-grant-types: client_credentials,refresh_token
        scope: openid,cloud_controller_service_permissions.read
        secret: (( merge ))
      route_advertise_client:
         authorities: route.advertise
         authorized_grant_type: client_credentials
         secret: ${common_password}
    scim:
      userids_enabled: true
      users:
      - admin|${common_password}|scim.write,scim.read,openid,cloud_controller.admin,uaa.admin,password.write,doppler.firehose
      - services|${common_password}|scim.write,scim.read,openid,cloud_controller.admin
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

