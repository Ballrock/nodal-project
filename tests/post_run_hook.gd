extends "res://addons/gut/hook_script.gd"

func run():
    print("--- Generating Coverage Report ---")
    var coverage_script = load("res://addons/coverage/coverage.gd")
    if coverage_script.instance:
        # Verbosity: 5 (ALL_FILES) for detailed lines, 1 for filenames
        coverage_script.instance.set_coverage_targets(80.0, 50.0)
        print(coverage_script.instance.script_coverage(1))
        
        # Save to JSON for external tools
        coverage_script.instance.save_coverage_file("res://coverage.json")
        print("Coverage report saved to res://coverage.json")
    else:
        print("Error: Coverage instance not found in post_run_hook.")
    print("--- Coverage Generation Complete ---")
