import os
import glob
import sys

def update_blend_imports(directory, new_scale):
    pattern = os.path.join(directory, '**/*.blend.import')
    files = glob.glob(pattern, recursive=True)
    count = 0
    
    for file_path in files:
        with open(file_path, 'r') as f:
            lines = f.readlines()
            
        modified = False
        for i, line in enumerate(lines):
            if line.startswith('nodes/root_scale='):
                lines[i] = f'nodes/root_scale={new_scale}\n'
                modified = True
                
        if modified:
            with open(file_path, 'w') as f:
                f.writelines(lines)
            count += 1
            print(f"Updated: {file_path}")
            
    print(f"\nDone! Updated {count} tiles files to scale {new_scale}.")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        directory = sys.argv[1]
        scale = sys.argv[2]
        update_blend_imports(directory, scale)
    else:
        print("Usage: python script.py <directory> <scale>")
