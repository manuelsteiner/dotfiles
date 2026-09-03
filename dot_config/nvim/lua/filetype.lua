-- Filetype refinements for YAML so the right language server attaches:
--   * Compose files            -> yaml.docker-compose  (docker_language_server + yamlls)
--   * YAML inside an Ansible    -> yaml.ansible         (ansiblels)
--     project (ansible.cfg ancestor)
--   * everything else           -> yaml                 (yamlls)

vim.filetype.add({
    filename = {
        ["compose.yaml"] = "yaml.docker-compose",
        ["compose.yml"] = "yaml.docker-compose",
        ["docker-compose.yaml"] = "yaml.docker-compose",
        ["docker-compose.yml"] = "yaml.docker-compose",
    },
    pattern = {
        [".*%.ya?ml"] = function(path)
            local found = vim.fs.find("ansible.cfg", {
                upward = true,
                path = vim.fs.dirname(path),
                stop = vim.uv.os_homedir(),
            })
            if found[1] then
                return "yaml.ansible"
            end
        end,
    },
})
