"""Inspect saved Blender geometry and every authored frame, before encoding.

blender -b --python scripts/animation/validate_toast_scenes.py -- /tmp/PetitChef-toast-scenes
"""
import bpy
import bmesh
import math
import sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

root = Path(sys.argv[sys.argv.index('--')+1])
names = ['toast-preheat', 'toast-cutting', 'toast-building', 'toast-baking',
         'toast-seasoning', 'toast-plating']


def meshes(prefix):
    return [obj for obj in bpy.context.scene.objects if obj.type == 'MESH' and obj.name.startswith(prefix)]


def volume(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    result = mesh.calc_volume(signed=False)
    mesh.free()
    return result


def bottom(obj):
    return min((obj.matrix_world @ vertex.co).z for vertex in obj.data.vertices)


checks = 0


def require(condition, message):
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1


for name in names:
    bpy.ops.wm.open_mainfile(filepath=str(root/name/(name+'.blend')))
    scene = bpy.context.scene
    objects = scene.objects
    if name == 'toast-preheat':
        require(not any('Pain' in obj.name or 'Plaque' in obj.name or 'Tartine' in obj.name
                        for obj in objects), 'Food must not appear during preheating')
        for frame in range(1, scene.frame_end+1):
            scene.frame_set(frame)
            require(Vector(objects['Porte articulée'].rotation_euler).length < 1e-6,
                    'Preheat door must remain shut')
        require(abs(objects['Thermostat'].rotation_euler.y-1.05) < 1e-5,
                'Thermostat must finish at its 180 °C graduation')
        for obj in meshes(''):
            for vertex in obj.data.vertices:
                point = world_to_camera_view(scene, scene.camera, obj.matrix_world @ vertex.co)
                require(.02 < point.x < .98 and .02 < point.y < .98,
                        'The preheat oven must remain fully inside the frame')
    elif name == 'toast-cutting':
        for prefix, expected_count, source_key in [
            ('Morceau de tomate conservé', 12, 'tomato_half_volume'),
            ('Tranche découpée de mozzarella', 6, 'mozzarella_volume'),
            ('Demi-gousse découpée', 2, 'garlic_volume')]:
            pieces = meshes(prefix)
            require(len(pieces) == expected_count, prefix+' has an unexpected piece count')
            actual_volume = sum(volume(obj) for obj in pieces)
            require(abs(actual_volume-scene[source_key]) < 1e-4,
                    f'{prefix}: volume {actual_volume:.8f}, expected {scene[source_key]:.8f}')
        blade = objects['Lame en acier']
        foods = meshes('Morceau de tomate')+meshes('Tranche découpée')+meshes('Demi-gousse')
        for frame in range(1, scene.frame_end+1):
            scene.frame_set(frame)
            require(bottom(blade) >= .179, f'Knife below the board at frame {frame}')
            for obj in foods:
                require(bottom(obj) >= .179, f'{obj.name} below the board at frame {frame}')
        require(abs(objects['Couteau de cuisine'].rotation_euler.x-math.pi/2) < 1e-5,
                'The knife must finish lying on its side')
    elif name == 'toast-baking':
        scene.frame_set(1)
        require(abs(objects['Thermostat'].rotation_euler.y-1.05) < 1e-5,
                'Baking must start with the oven already set')
        scene.frame_set(68)
        require(abs(objects['Plaque et tartines préparées'].location.y) < 1e-5,
                'Tray must finish moving before the door closes')
        require(abs(objects['Porte articulée'].rotation_euler.x-math.pi/2) < 1e-5,
                'Door must stay fully open until tray insertion ends')
    elif name == 'toast-seasoning':
        for frame in range(1, scene.frame_end+1):
            scene.frame_set(frame)
            for obj in meshes('Dé de tomate'):
                for vertex in obj.data.vertices:
                    point = obj.matrix_world @ vertex.co
                    radius = math.hypot(point.x, point.y/.82)
                    floor = .22+max(0, radius-.65)*(.53/.77)
                    require(radius < 1.70 and point.z >= floor-.002,
                            f'Tomato through the bowl at frame {frame}')
    elif name == 'toast-plating':
        cheese = meshes('Mozzarella fondue')
        require(len(cheese) == 6 and all(obj.animation_data is None for obj in cheese),
                'Plating must start with the already-melted cheese')
        loaves = [obj for obj in objects if obj.name.startswith('Tartine déjà gratinée')]
        require(len(loaves) == 2 and all(obj.animation_data is None for obj in loaves),
                'Plating must not restart bread assembly')
    if name in ['toast-building', 'toast-seasoning']:
        bottle = objects['Bouteille d’huile']
        streams = [obj for obj in objects if obj.name.startswith('Huile reliée au goulot')]
        for frame in range(1, scene.frame_end+1):
            scene.frame_set(frame)
            for stream in streams:
                if stream.hide_render:
                    continue
                mouth = bottle.matrix_world @ Vector((0, 0, 1.28))
                anchor = Vector(stream.data.splines[0].points[0].co[:3])
                require((mouth-anchor).length < 1e-5,
                        f'Oil detached from the bottle at frame {frame}')
    print('VALIDATED:', name, flush=True)
    if '--render-inspection' in sys.argv:
        frames = {
            'toast-preheat': [18, 48, 76, 144],
            'toast-cutting': [21, 35, 49, 68, 85, 99, 123, 147, 169, 192],
            'toast-building': [20, 59, 86, 115, 159, 192],
            'toast-baking': [20, 68, 94, 144],
            'toast-seasoning': [18, 61, 96, 144, 192],
            'toast-plating': [1, 56, 86, 118, 144],
        }[name]
        destination = root/name/'inspection'
        destination.mkdir(exist_ok=True)
        for frame in frames:
            scene.frame_set(frame)
            scene.render.filepath = str(destination/f'pose-{frame:03}.png')
            bpy.ops.render.render(write_still=True)

print(f'{checks} geometry and motion checks passed.', flush=True)
