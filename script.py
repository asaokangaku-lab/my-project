import os

INPUT_DIR = "input"
OUTPUT_DIR = "output"

os.makedirs(OUTPUT_DIR, exist_ok=True)

for filename in os.listdir(INPUT_DIR):
    filepath = os.path.join(INPUT_DIR, filename)

    if os.path.isfile(filepath):
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()

        summary = content[:100]

        new_filename = f"processed_{filename}"
        output_path = os.path.join(OUTPUT_DIR, new_filename)

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(summary)