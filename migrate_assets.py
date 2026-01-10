import os
import json
import shutil

source_dir = "/Users/travis/Documents/projects/claude-usage-pro/Sources/ClaudeUsagePro/Assets"
dest_dir = "/Users/travis/Documents/projects/claude-usage-pro/Sources/ClaudeUsagePro/Assets.xcassets"

if os.path.exists(dest_dir):
    shutil.rmtree(dest_dir)
os.makedirs(dest_dir)

# Create root Contents.json
with open(os.path.join(dest_dir, "Contents.json"), "w") as f:
    json.dump({
        "info": {
            "author": "xcode",
            "version": 1
        }
    }, f, indent=2)

files = [f for f in os.listdir(source_dir) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]

for filename in files:
    name_without_ext = os.path.splitext(filename)[0]
    imageset_dir = os.path.join(dest_dir, f"{name_without_ext}.imageset")
    os.makedirs(imageset_dir)
    
    # Copy file
    shutil.copy2(os.path.join(source_dir, filename), os.path.join(imageset_dir, filename))
    
    # Create Contents.json
    with open(os.path.join(imageset_dir, "Contents.json"), "w") as f:
        json.dump({
            "images": [
                {
                    "filename": filename,
                    "idiom": "universal",
                    "scale": "1x"
                },
                {
                    "idiom": "universal",
                    "scale": "2x"
                },
                {
                    "idiom": "universal",
                    "scale": "3x"
                }
            ],
            "info": {
                "author": "xcode",
                "version": 1
            }
        }, f, indent=2)

print("Migration complete")
