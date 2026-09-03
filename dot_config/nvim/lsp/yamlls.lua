-- yamlls runs in a container with --network=none. Disable the SchemaStore
-- catalog (unreachable by design); the `# yaml-language-server: $schema=`
-- modeline and explicit local schema mappings still work.
return {
    settings = {
        yaml = {
            schemaStore = { enable = false, url = "" },
        },
    },
}
