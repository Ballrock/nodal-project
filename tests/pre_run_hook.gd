extends "res://addons/gut/hook_script.gd"

func run():
    print("--- Initializing Coverage Instrumentation ---")
    var coverage_script = load("res://addons/coverage/coverage.gd")
    # GutHookScript has a 'gut' property, which is a Node
    var coverage = coverage_script.new(gut.get_tree(), ["res://addons/*", "res://tests/*", "res://specs/*"])
    
    # Instrument all source directories
    coverage.instrument_scripts("res://core")
    coverage.instrument_scripts("res://features")
    coverage.instrument_scripts("res://ui")
    
    # Store instance for post_run_script
    print("--- Instrumentation Complete ---")
