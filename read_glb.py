import json
import struct

def parse_glb(file_path, out_file):
    with open(file_path, 'rb') as f:
        magic = f.read(4)
        if magic != b'glTF':
            with open(out_file, 'w') as out: out.write("Not a GLB file\n")
            return
        
        version = struct.unpack('<I', f.read(4))[0]
        length = struct.unpack('<I', f.read(4))[0]
        
        chunk0_length = struct.unpack('<I', f.read(4))[0]
        chunk0_type = f.read(4)
        
        if chunk0_type != b'JSON':
            with open(out_file, 'w') as out: out.write("First chunk is not JSON\n")
            return
            
        json_data = f.read(chunk0_length)
        gltf = json.loads(json_data.decode('utf-8'))
        
        with open(out_file, 'w') as out:
            import pprint
            # check the asset block for unit scaling
            out.write("Asset info: " + str(gltf.get('asset', {})) + "\n")
            
            for i, node in enumerate(gltf.get('nodes', [])):
                scale = node.get('scale', [1.0, 1.0, 1.0])
                translation = node.get('translation', [0.0, 0.0, 0.0])
                name = node.get('name', f'Node_{i}')
                out.write(f"Node '{name}': Scale {scale}, Translation {translation}\n")
                
            for i, mesh in enumerate(gltf.get('meshes', [])):
                out.write(f"Mesh {i} Name: {mesh.get('name', '')}\n")

parse_glb('/home/khanhromvn/Documents/entropy/assets/environment/props/autumn_yellow_tree/autumn_yellow_tree.glb', '/tmp/glb_result.txt')
