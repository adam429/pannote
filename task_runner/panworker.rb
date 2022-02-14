# load init moudle file

$data_import = true
load "./panbot_note.rb"

node_name = ENV["WORKER_NAME"]
Task.run_loop(node_name)