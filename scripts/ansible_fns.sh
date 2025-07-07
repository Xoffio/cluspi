create_python_venv() {
	cd "$SCRIPT_DIR" || exit 1
	if [ ! -d "./dev" ]; then
		python3 -m venv dev || echo "Failed creating virtual environment" && exit 1
	fi
}

activate_python_venv() {
	cd "$SCRIPT_DIR" || exit 1
	source dev/bin/activate
	pip install -r requirements.txt
}
