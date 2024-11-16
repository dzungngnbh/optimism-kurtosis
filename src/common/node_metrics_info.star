# this is a dictionary as this will get serialzed to JSON
def new(
        name,
        path,
        url,
        config=None,
):
    return {
        "name": name,
        "path": path,
        "url": url,
        "config": config,
    }