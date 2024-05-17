import subprocess
import sys

# ==============================================
# main
# ==============================================
if __name__ == "__main__":
    scripts = [
        "/app/pre-processor/templatizer.py"
        #"/app/clusterer/online_clustering.py",
    ]

    for script in scripts:
        result = subprocess.run([sys.executable, script], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Error running {script}: {result.stderr}")
            sys.exit(result.returncode)
        print(f"Successfully Running {script}: {result.stdout}")
