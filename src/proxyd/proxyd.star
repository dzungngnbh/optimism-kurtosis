redis = import_module("github.com/kurtosis-tech/redis-package/main.star")
utils = import_module("../common/utils.star")
IMAGE = "docker.io/dzungngnbh/proxyd:latest"

# The min/max CPU/memory that redis can use
REDIS_MIN_CPU = 10
REDIS_MAX_CPU = 1000
REDIS_MIN_MEMORY = 32
REDIS_MAX_MEMORY = 1024

def run(plan, l2_el_context):
    proxyd_config = plan.upload_files(
        src="/static_files/proxyd/proxyd.toml",
        name="proxyd-config",
    )

    redis_uri = redis.run(
        plan,
        service_name="proxyd-redis",
        min_cpu=REDIS_MIN_CPU,
        max_cpu=REDIS_MAX_CPU,
        min_memory=REDIS_MIN_MEMORY,
        max_memory=REDIS_MAX_MEMORY,
    )

    service_config = ServiceConfig(
        image=IMAGE,
        ports={
            "rpc": utils.new_port_spec(8080),
            "admin": utils.new_port_spec(8888),
        },
        public_ports={
            "rpc": utils.new_port_spec(8080),
            "admin": utils.new_port_spec(8888),
        },
        env_vars={
            "REDIS_URI": redis_uri.url,
            # TODO: This should be in config file
            "ADMIN_KEY": "<admin-key>",
            "DATABASE_URL": "<database-url>",

            "RPC_HTTP_URL": l2_el_context.rpc_http_url,
            "RPC_WS_URL": l2_el_context.ws_url
        },
        files={
            "/etc/proxyd/": proxyd_config
        },
        cmd=[
            "/bin/sh",
            "-c",
            "/bin/proxyd /etc/proxyd/proxyd.toml",
        ],
    )

    plan.add_service("proxyd", service_config)
