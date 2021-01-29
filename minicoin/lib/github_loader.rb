def evaluate_expression(expression, context)
    expression = expression.dup
    if expression.include?("${{")
        token = "[a-zA-Z0-9_\(\)]*"
        matches = expression.scan(/\$\{\{ (#{token})\.?(#{token})?\.?(#{token})?\.?(#{token})? \}\}/)
        matches.each do |captures|
            value = nil
            variable = "${{ "
            captures.each do |capture|
                next if capture.empty?
                if value.nil?
                    value = context[capture]
                    variable += capture
                else
                    value = value[capture]
                    variable += ".#{capture}"
                end
            end
            variable += " }}"
            expression[variable] = value || ""
        end
    end
    return expression
end

def load_github(yaml)
    return if ENV['MINICOIN_PROJECT_DIR'].nil?
    github_machines = []
    github_root = find_config(ENV['MINICOIN_PROJECT_DIR'], ".github")
    while github_root
        github_workflow = YAML.load_file("#{github_root}/.github/workflows/ninja-build.yml")
        jobs = github_workflow["jobs"]
        jobs.each do |jobname, job|
            begin
                matrix_includes = job["strategy"]["matrix"]["include"]
            rescue
                matrix_includes = []
            end
            matrix_includes.each do |matrix_entry|
                minicoin_box = yaml["github"][matrix_entry["os"]]
                if minicoin_box.nil?
                    STDERR.puts "#{__FILE__}: No vagrant box mapped to #{matrix_entry['os']}"
                    next
                end
                github_machine = {
                    "name" => "github-#{matrix_entry['name']}",
                    "box" => minicoin_box["box"],
                    "_github" => {
                        "runner" => minicoin_box["runner"],
                        "matrix" => matrix_entry,
                        "failure()" => false
                    }
                }
                github_machine["roles"] = minicoin_box["roles"] || []
                github_machine["jobs"] = []
                github_machines << github_machine
            end
            github_machines.each do |github_machine|
                steps = job["steps"]
                found_job = false
                shell = github_workflow["defaults"]["run"]["shell"]
                shellcmd = yaml["github"]["shells"][shell]
                context = github_machine["_github"]

                job_script = [ "echo 'Running Job #{jobname}' on #{github_machine['name']}" ]
                steps.each do |step|
                    if step["if"]
                        condition = step["if"]
                        #condition = condition.gsub(/^([a-zA-Z0-9_]*)\.([a-zA-Z0-9_]*)/, 'github_machine["_github"]["\1"]["\2"]')
                        condition = condition.gsub(/^([a-zA-Z0-9_]*)\.([a-zA-Z0-9_]*)/, '"${{ \1.\2 }}"')
                        condition = evaluate_expression(condition, context)
                        next if !eval(condition)
                    end
                    if step["run"]
                        working_directory = step["working-directory"]
                        job_script << "echo \"==> Running #{step['name']} from $(pwd)\""
                        job_script << "cd #{working_directory}" if working_directory

                        job_script << evaluate_expression(step["run"], context)
                        job_script << "cd -" if working_directory
                    end
                end
                github_machine["jobs"] += [
                    {
                        "job" => "github",
                        "shell" => shellcmd,
                        "workflow" => job_script.join("\n")
                    }.merge(github_machine["_github"]["runner"]["minicoin_flags"] || {})
                ]
                github_machine.delete("_github")
            end
        end
        github_root = find_config(File.dirname(github_root), ".github")
    end

    github_config = {}
    github_config["machines"] = github_machines
    return github_config
end
