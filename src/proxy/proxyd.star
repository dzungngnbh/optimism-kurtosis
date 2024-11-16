redis = import_module("github.com/kurtosis-tech/redis-package/main.star")
utils = import_module("../common/utils.star")
IMAGE = "docker.io/dzungngnbh/proxyd:latest"

# The min/max CPU/memory that redis can use
REDIS_MIN_CPU = 10
REDIS_MAX_CPU = 1000
REDIS_MIN_MEMORY = 32
REDIS_MAX_MEMORY = 1024

def run(plan):
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
            "http": utils.new_port_spec(8080),
        },
        public_ports={
            "http": utils.new_port_spec(8080),
        },
        env_vars={
            "REDIS_URI": redis_uri.url,
            "ADMIN_KEY": "admin",
            "DATABSE_URL": "postgresql://postgres.icudzglqdhghkyjpgzhu:D3WGoVkfxHAi7jzfrh8N@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres",
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
