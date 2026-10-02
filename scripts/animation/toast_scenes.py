"""Six authored recipe scenes; Blender 5.2, no downloaded models.

blender -b --python scripts/animation/toast_scenes.py -- /tmp/toast-scenes --preview-only
Omit --preview-only to render frames. --scene toast-cutting renders one scene.
"""
import bpy
import bmesh
import math
import random
import sys
from pathlib import Path
from mathutils import Vector, Euler

sys.path.insert(0, str(Path(__file__).resolve().parent))
import toast_scene_tools as art

OUT = Path(sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else '/tmp/toast-scenes')
SCENES = {'toast-preheat': 144, 'toast-cutting': 192, 'toast-building': 192,
          'toast-baking': 144, 'toast-seasoning': 192, 'toast-plating': 144}
TAU = math.tau
wood = art.material('Planche en bois clair', (.81, .66, .44))
steel = art.material('Acier mat', (.69, .73, .69))
dark = art.material('Verre du four', (.22, .27, .24))
oil = art.material('Huile d’olive', (.73, .64, .26))
warm = art.material('Lumière chaude', (.97, .74, .35))
glass = bpy.data.materials.new('Vitre légèrement teintée')
glass.use_nodes = True
glass.surface_render_method = 'BLENDED'
nodes = glass.node_tree.nodes
nodes.clear()
output = nodes.new('ShaderNodeOutputMaterial')
transparent = nodes.new('ShaderNodeBsdfTransparent')
tint = nodes.new('ShaderNodeEmission')
tint.inputs['Color'].default_value = (.22, .27, .24, 1)
mix = nodes.new('ShaderNodeMixShader')
mix.inputs[0].default_value = .22
glass.node_tree.links.new(transparent.outputs[0], mix.inputs[1])
glass.node_tree.links.new(tint.outputs[0], mix.inputs[2])
glass.node_tree.links.new(mix.outputs[0], output.inputs[0])


def cube(name, xyz, size, mat, parent=None, bevel=.06, outline=False):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Angles adoucis', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    art.finish(obj, mat, outline)
    obj.parent = parent
    obj.location = xyz
    return obj


def ellipse(name, rx, ry, z, mat, parent=None, radius=.007):
    return art.curve(name, [(rx*math.cos(i*TAU/96), ry*math.sin(i*TAU/96), z)
                            for i in range(97)], radius, mat, parent)


def sphere(name, xyz, size, mat, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    art.finish(obj, mat)
    obj.parent = parent
    obj.location = xyz
    return obj


def animate(obj, frames):
    art.keys(obj, [(f, loc, rot) for f, loc, rot in frames])


def mesh_bottom(obj, rotation=(0, 0, 0)):
    matrix = Euler(rotation).to_matrix()
    return min((matrix @ vertex.co).z for vertex in obj.data.vertices)


def mesh_volume(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    volume = mesh.calc_volume(signed=False)
    mesh.free()
    return volume


def triangulate(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.triangulate(mesh, faces=list(mesh.faces))
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()


def on_surface(obj, x, y, height, rotation=(0, 0, 0)):
    return (x, y, height-mesh_bottom(obj, rotation)+.003)


def intersect_piece(source, lower, upper, name):
    """Real, volume-conserving cuts. No new food appears after knife contact."""
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    cutter = cube('Volume de coupe temporaire',
                  tuple((a+b)/2 for a, b in zip(lower, upper)),
                  tuple(b-a for a, b in zip(lower, upper)), art.cheese, bevel=0)
    # Cut faces use the second material; the original skin remains on the outside.
    cutter.data.materials.clear()
    cutter.data.materials.append(source.data.materials[-1])
    mod = obj.modifiers.new('Découpe solide', 'BOOLEAN')
    mod.operation = 'INTERSECT'
    mod.solver = 'EXACT'
    mod.object = cutter
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    # Rebase each mesh to its own centre so pieces tip without changing volume.
    centre = sum((Vector(corner) for corner in obj.bound_box), Vector()) / 8
    for vertex in obj.data.vertices:
        vertex.co -= centre
    obj.location += centre
    for polygon in obj.data.polygons:
        planar = max(abs(polygon.normal.x), abs(polygon.normal.y), abs(polygon.normal.z)) > .9999
        polygon.material_index = len(obj.data.materials)-1 if planar else 0
        polygon.use_smooth = not planar
    obj.data.update()
    return obj


def pouring_stream(bottle, start, end, landing):
    """Bake the fluid endpoints from the animated neck at every frame."""
    obj = art.curve('Huile reliée au goulot', [(0, 0, 0)]*8, .013, oil)
    points = obj.data.splines[0].points
    for frame in range(start, end+1):
        bpy.context.scene.frame_set(frame)
        mouth = bottle.matrix_world @ Vector((0, 0, 1.28))
        target = Vector(landing(frame))
        for index, point in enumerate(points):
            t = index/(len(points)-1)
            position = mouth.lerp(target, t)
            position.x += .035*math.sin(math.pi*t)
            point.co = (*position, 1)
            point.keyframe_insert(data_path='co', frame=frame)
    for frame, hidden in [(1, True), (start, False), (end+1, True)]:
        obj.hide_render = hidden
        obj.keyframe_insert(data_path='hide_render', frame=frame)
    return obj


def appear(obj, start, duration=5):
    base = obj.scale.copy()
    for f, s in [(1, 0), (start, 0), (start+duration, 1)]:
        obj.scale = base*s
        obj.keyframe_insert(data_path='scale', frame=f)


def vanish(obj, frame):
    base = obj.scale.copy()
    for f, s in [(1, 1), (frame, 1), (frame+1, 0)]:
        obj.scale = base*s
        obj.keyframe_insert(data_path='scale', frame=f)


def drop(obj, xyz, start, duration=15):
    x, y, z = xyz
    appear(obj, start, 4)
    animate(obj, [(1, (x, y, z+2.3), (.12, -.12, .15)),
                  (start, (x, y, z+2.3), (.12, -.12, .15)),
                  (start+duration, xyz, (0, 0, 0))])


def reveal_curve(obj, start, duration, end=None):
    for frame, amount in [(1, 0), (start, 0), (start+duration, 1)]:
        obj.data.bevel_factor_end = amount
        obj.data.keyframe_insert(data_path='bevel_factor_end', frame=frame)
    for layer in obj.data.animation_data.action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fcurve in bag.fcurves:
                    for key in fcurve.keyframe_points:
                        key.interpolation = 'LINEAR'
    if end:
        for frame, hidden in [(1, True), (start, False), (end, True)]:
            obj.hide_render = hidden
            obj.keyframe_insert(data_path='hide_render', frame=frame)


def board():
    cube('Planche à découper', (0, 0, .09), (6.1, 3.6, .18), wood, bevel=.18)
    for j in range(12):
        y = -1.55 + j*.28
        art.curve('Fibre du bois', [(-2.7, y, .183), (-1.2, y+.035, .184),
                                   (.5, y-.022, .184), (2.7, y+.01, .183)], .003, art.poremat)


def bread(name, xyz):
    root = art.empty(name)
    root.location = xyz
    art.ringmesh('Croûte de campagne', [(1.08, .73, 0), (1.11, .75, .08),
                                       (1.06, .70, .30), (.98, .65, .33)], art.crust, root, .025)
    art.ringmesh('Mie', [(.95, .625, .329), (.96, .63, .338)], art.crumb, root, .025)
    ellipse('Contour de croûte', 1.07, .705, .30, art.ink, root, .008)
    for _ in range(32):
        a = random.uniform(0, TAU)
        r = math.sqrt(random.random())*.88
        sphere('Alvéole', (math.cos(a)*r, math.sin(a)*r*.63, .342),
               (random.uniform(.015, .04), random.uniform(.012, .028), .005), art.poremat, root)
    for j in range(12):
        a = math.pi + j*.18
        art.curve('Hachure', [(1.10*math.cos(a), .74*math.sin(a), .10),
                             (1.07*math.cos(a+.04), .705*math.sin(a+.04), .25)], .003, art.ink, root)
    return root


def mozzarella(xyz, parent=None, melted=False):
    profile = [(.36, .29, 0), (.40, .31, .035), (.38, .29, .075), (.32, .25, .085)]
    if melted:
        profile = [(.38, .30, 0), (.43, .34, .012), (.41, .32, .039), (.34, .26, .05)]
    obj = art.ringmesh('Mozzarella fondue' if melted else 'Mozzarella égouttée',
                       profile, art.cheese, parent, .045)
    ellipse('Contour du fromage', profile[-2][0], profile[-2][1], profile[-2][2], art.ink, obj, .004)
    obj.location = xyz
    return obj


def leaf(xyz, parent=None):
    verts, faces = [], []
    for j in range(17):
        t = j/16
        w = math.sin(math.pi*t)*.19
        y = (t-.5)*.72
        verts.extend([(-w, y, .025*math.sin(math.pi*t)),
                      (0, y, .075*math.sin(math.pi*t)), (w, y, .025*math.sin(math.pi*t))])
    for j in range(16):
        for c in range(2):
            faces.append((j*3+c, j*3+c+1, (j+1)*3+c+1, (j+1)*3+c))
    mesh = bpy.data.meshes.new('Feuille de basilic')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Basilic nervuré', mesh)
    bpy.context.collection.objects.link(obj)
    art.finish(obj, art.green)
    obj.parent = parent
    obj.location = xyz
    art.curve('Nervure', [(0, (j/16-.5)*.72, .08*math.sin(math.pi*j/16)+.004)
                         for j in range(17)], .005, art.veinmat, obj)
    for j in range(1, 7):
        t = j/8
        for sign in [-1, 1]:
            art.curve('Nervure fine', [(0, (t-.5)*.72, .08*math.sin(math.pi*t)),
                                      (sign*.16*math.sin(math.pi*t), (t-.5)*.72+.04,
                                       .035*math.sin(math.pi*t))], .003, art.veinmat, obj)
    return obj


def tomato(xyz, parent=None):
    obj = cube('Dé de tomate', xyz, (.30, .27, .23), art.red, parent, .035, True)
    sphere('Graine de tomate', (.025, -.01, .12), (.018, .033, .006), art.seedmat, obj)
    art.curve('Chair claire', [(-.10, -.08, .117), (-.04, -.10, .121), (.02, -.08, .123)],
              .007, art.seedmat, obj)
    return obj


def garlic(xyz):
    obj = art.ringmesh('Demi-gousse d’ail', [(.09, .07, 0), (.22, .14, .06),
                                          (.20, .12, .18), (.08, .06, .34), (.01, .01, .40)], art.cheese)
    obj.location = xyz
    art.curve('Strie de l’ail', [(0, -.145, .06), (0, -.12, .18), (0, -.06, .34)],
              .004, art.poremat, obj)
    return obj


def oil_bottle(xyz):
    obj = art.ringmesh('Bouteille d’huile', [(.21, .18, 0), (.24, .20, .1),
                                          (.24, .20, .75), (.1, .09, .9), (.09, .08, 1.2)], art.green)
    obj.location = xyz
    cube('Étiquette crème', (0, -.204, .42), (.34, .015, .3), art.cream, obj, .02)
    art.ringmesh('Goulot ouvert', [(.1, .09, 1.2), (.1, .09, 1.28),
                                 (.075, .065, 1.28), (.075, .065, 1.2)], oil, obj)
    return obj


def knife():
    root = art.empty('Couteau de cuisine')
    # Thin solid blade: tip on the left, bolster and riveted handle on the right.
    verts = [(-1.12, -.027, 0), (.4, -.027, 0), (.4, -.027, .43),
             (-.85, -.027, .32), (-1.12, .027, 0), (.4, .027, 0),
             (.4, .027, .43), (-.85, .027, .32)]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2),
             (2, 6, 7, 3), (3, 7, 4, 0)]
    mesh = bpy.data.meshes.new('Lame pleine')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    blade = bpy.data.objects.new('Lame en acier', mesh)
    bpy.context.collection.objects.link(blade)
    art.finish(blade, steel)
    blade.parent = root
    art.curve('Fil de lame', [(-1.12, -.03, .007), (.40, -.03, .007)], .005, art.ink, root)
    cube('Manche du couteau', (.94, 0, .24), (1.06, .18, .24), art.ink, root, .06)
    for x in [.66, 1.12]:
        sphere('Rivet', (x, -.094, .24), (.028, .007, .028), art.cream, root)
    return root


def oven(baking=False):
    # Empty preheat scene; baking reuses the same oven already set to 180 °C.
    cube('Paroi arrière', (0, .93, 1.65), (4.4, .18, 2.8), art.cream)
    for x in [-2.12, 2.12]:
        cube('Paroi du four', (x, 0, 1.65), (.18, 2.0, 2.8), art.cream)
    cube('Dessus du four', (0, 0, 3.03), (4.4, 2.1, .16), art.cream)
    cube('Sole', (0, 0, .38), (4.4, 2.1, .18), art.cream)
    cube('Bandeau', (0, -1.06, 2.72), (4.28, .15, .56), art.cream)
    for x in [-1.9, 1.9]:
        cube('Pied', (x, -.6, .18), (.22, .4, .26), art.ink)
    cube('Fond de cavité', (0, .824, 1.51), (3.95, .015, 2.0), dark, bevel=.02)
    for x in [-1.75, -.9, 0, .9, 1.75]:
        art.curve('Barre de grille', [(x, -.86, .86), (x, .75, .86)], .016, steel)
    art.curve('Grille avant', [(-1.8, -.87, .86), (1.8, -.87, .86)], .019, art.ink)
    knob = art.empty('Thermostat')
    knob.location = (1.10, -1.17, 2.72)
    ring = art.ringmesh('Bouton de température', [(.22, .22, 0), (.23, .23, .09)], steel, knob)
    ring.rotation_euler = (math.pi/2, 0, 0)
    art.curve('Repère du thermostat', [(0, -.105, .07), (0, -.105, .17)], .015, art.ink, knob)
    # A y rotation sends the upward mark towards +x. Target graduation matches it.
    target_angle = 1.05
    for angle in [-1.05, -.525, 0, .525, 1.05, 1.575, 2.10]:
        art.curve('Graduation', [(1.10+.31*math.sin(angle), -1.15, 2.72+.31*math.cos(angle)),
                                (1.10+.36*math.sin(angle), -1.15, 2.72+.36*math.cos(angle))], .008, art.ink)
    bpy.ops.object.text_add(location=(1.10+.43*math.sin(target_angle), -1.151,
                                      2.72+.43*math.cos(target_angle)), rotation=(math.pi/2, 0, 0))
    label = bpy.context.object
    label.data.body = '180°C'
    label.data.size = .14
    label.data.align_x = 'CENTER'
    label.data.align_y = 'CENTER'
    label.data.materials.append(art.ink)
    socket = sphere('Support du voyant', (-1.25, -1.15, 2.72), (.070, .019, .070), art.ink)
    lamp = sphere('Voyant de chauffe', (-1.25, -1.172, 2.72), (.045, .009, .045), warm)
    element_material = bpy.data.materials.new('Résistance électrique incandescente')
    element_material.use_nodes = True
    element_nodes = element_material.node_tree.nodes
    element_nodes.clear()
    element_output = element_nodes.new('ShaderNodeOutputMaterial')
    emission = element_nodes.new('ShaderNodeEmission')
    element_material.node_tree.links.new(emission.outputs[0], element_output.inputs[0])
    points = []
    for j in range(7):
        x = -1.65+j*.55
        points.extend([(x, -.68 if j%2==0 else .66, .57),
                       (x, .66 if j%2==0 else -.68, .57)])
    art.curve('Résistance sous la grille', points, .023, element_material)
    for frame, color in ([(1, (.80, .36, .10, 1))] if baking else
                         [(1, (.23, .27, .24, 1)), (42, (.23, .27, .24, 1)),
                          (76, (.80, .36, .10, 1))]):
        emission.inputs['Color'].default_value = color
        emission.inputs['Color'].keyframe_insert(data_path='default_value', frame=frame)
    if baking:
        knob.rotation_euler.y = target_angle
    else:
        animate(knob, [(1, knob.location[:], (0, 0, 0)),
                       (18, knob.location[:], (0, 0, 0)),
                       (48, knob.location[:], (0, target_angle, 0))])
        appear(lamp, 38, 6)
    door = art.empty('Porte articulée')
    door.location = (0, -1.08, .47)
    for x in [-1.97, 1.97]:
        cube('Montant de porte', (x, 0, .92), (.2, .12, 1.84), steel, door)
    for z in [.08, 1.79]:
        cube('Traverse de porte', (0, 0, z), (4.0, .12, .16), steel, door)
    cube('Vitre', (0, .028, .92), (3.72, .026, 1.57), glass, door, .07)
    art.curve('Poignée du four', [(-1.2, -.2, 1.63), (-1.2, -.30, 1.63),
                                (1.2, -.30, 1.63), (1.2, -.2, 1.63)], .055, art.ink, door)
    if baking:
        animate(door, [(1, door.location[:], (0, 0, 0)),
                       (20, door.location[:], (math.pi/2, 0, 0)),
                       (70, door.location[:], (math.pi/2, 0, 0)),
                       (94, door.location[:], (0, 0, 0))])
        tray = prepared_tray()
        tray.scale = (.76, .76, .76)
        animate(tray, [(1, (0, -3.0, .90), (0, 0, 0)),
                       (34, (0, -3.0, .90), (0, 0, 0)),
                       (68, (0, 0, .90), (0, 0, 0))])
        return (0, -.8, 1.3), 9.8
    return (0, 0, 1.70), 7.5


def prepared_tray(with_cheese=True):
    tray = art.empty('Plaque et tartines préparées')
    cube('Plaque de cuisson', (0, 0, 0), (4.8, 2.3, .10), steel, tray, .09)
    for x in [-1.15, 1.15]:
        loaf = bread('Pain sur la plaque', (x, 0, .06))
        loaf.parent = tray
        if with_cheese:
            for j in range(3):
                mozzarella((x+(j-1)*.50, 0, .407), tray)
    return tray


def cutting():
    board()
    blade = knife()
    skin = art.material('Peau de tomate', (.71, .22, .13))
    flesh = art.material('Chair fraîche', (.90, .39, .24))
    source = sphere('Demi-tomate source', (0, 0, 0), (.68, .57, .42), skin)
    source.data.materials.append(flesh)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.scene['tomato_half_volume'] = mesh_volume(source)/2
    # Half a tomato on its cut face; exact cuts conserve the food volume.
    for row in range(3):
        for col in range(4):
            lower = (-.68+col*.34, -.57+row*.38, 0)
            upper = (lower[0]+.34, lower[1]+.38, .43)
            piece = intersect_piece(source, lower, upper, 'Morceau de tomate conservé')
            # Seeds stay attached to actual cut faces, hidden inside the uncut half.
            for face in piece.data.polygons:
                if face.material_index != 1 or not (face.normal.y < -.99 or face.normal.x > .99):
                    continue
                point = face.center+face.normal*.005
                size = (.018, .006, .028) if face.normal.y < -.99 else (.006, .018, .028)
                sphere('Graine sur la face coupée', point, size, art.seedmat, piece)
            origin = piece.location.copy()+Vector((-1.45, -.20, .183))
            animate(piece, [(1, origin, (0, 0, 0)), (92, origin, (0, 0, 0)),
                            (105, origin+Vector(((col-1.5)*.12, (row-1)*.14, 0)), (0, 0, 0))])
    bpy.data.objects.remove(source, do_unlink=True)
    source = sphere('Mozzarella source', (0, 0, 0), (.44, .40, .42), art.cheese)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.scene['mozzarella_volume'] = mesh_volume(source)
    slice_width = .88/6
    for j in range(6):
        piece = intersect_piece(source, (-.44+j*slice_width, -.41, -.43),
                                (-.44+(j+1)*slice_width, .41, .43), 'Tranche découpée de mozzarella')
        origin = piece.location.copy()+Vector((.85, .25, .603))
        clear = 104+j*12 if j<3 else 152
        final_rotation = (0, math.pi/2, .02*(j-2.5))
        final = on_surface(piece, -.08+(j%3)*.86, -1.15 if j<3 else -.25, .183, final_rotation)
        animate(piece, [(1, origin, (0, 0, 0)), (clear+1, origin, (0, 0, 0)),
                        (clear+5, origin+Vector((0, -.40, .25)), (0, .7, 0)),
                        (clear+13, final, final_rotation)])
    bpy.data.objects.remove(source, do_unlink=True)
    source = garlic((0, 0, 0))
    triangulate(source)
    bpy.context.scene['garlic_volume'] = mesh_volume(source)
    for side in range(2):
        lower = (-.23 if side==0 else 0, -.15, -.01)
        upper = (0 if side==0 else .23, .15, .41)
        half = intersect_piece(source, lower, upper, 'Demi-gousse découpée')
        origin = half.location.copy()+Vector((2.10, .22, .183))
        rotation = (0, -.35 if side==0 else .35, 0)
        final = on_surface(half, 1.98 if side==0 else 2.40, .22, .183, rotation)
        animate(half, [(1, origin, (0, 0, 0)), (174, origin, (0, 0, 0)),
                       (185, final, rotation)])
    for child in list(source.children):
        bpy.data.objects.remove(child, do_unlink=True)
    bpy.data.objects.remove(source, do_unlink=True)
    beats = [(1, (-1.45, 0, 1.35), (0, 0, math.pi/2))]
    cuts = [(18, -1.79, 0, math.pi/2), (32, -1.45, 0, math.pi/2),
            (46, -1.11, 0, math.pi/2), (65, -1.14, -.39, 0),
            (82, -1.14, -.01, 0),
            *[(96+j*12, .85-.44+(j+1)*slice_width, .50, math.pi/2) for j in range(5)],
            (166, 2.10, .35, math.pi/2)]
    for f, x, y, angle in cuts:
        beats.extend([(f-4, (x, y, 1.05), (0, 0, angle)),
                      (f+3, (x, y, .185), (0, 0, angle)),
                      (f+7, (x, y, 1.05), (0, 0, angle))])
    # Lay the knife on its side; the blade and thicker handle determine its rest height.
    rest_rotation = (math.pi/2, -.04, -.10)
    rest_matrix = Euler(rest_rotation).to_matrix()
    rest_bottom = min((rest_matrix @ (obj.matrix_basis @ vertex.co)).z
                      for obj in blade.children if obj.type == 'MESH'
                      for vertex in obj.data.vertices)
    knife_rest = (1.20, 1.12, .183-rest_bottom)
    beats.extend([(184, knife_rest, rest_rotation), (192, knife_rest, rest_rotation)])
    animate(blade, beats)
    return (0, 0, .35), 8.0


def building():
    board()
    tray = prepared_tray(with_cheese=False)
    tray.location = (0, 0, .24)
    top = .24+.06+.338
    source = garlic((0, 0, 0))
    triangulate(source)
    clove = intersect_piece(source, (-.23, -.15, -.01), (0, .15, .41), 'Ail face coupée sur le pain')
    for child in list(source.children):
        bpy.data.objects.remove(child, do_unlink=True)
    bpy.data.objects.remove(source, do_unlink=True)
    rub_rotation = (0, math.pi/2, 0)
    contact = top-mesh_bottom(clove, rub_rotation)+.003
    resting = on_surface(clove, 2.66, .60, .183)
    animate(clove, [(1, (-1.50, 0, 1.35), rub_rotation),
                    (12, (-1.50, 0, contact), rub_rotation),
                    (20, (-.80, 0, contact), rub_rotation),
                    (29, (-1.50, 0, contact), rub_rotation),
                    (38, (-.80, 0, contact), rub_rotation),
                    (43, (-.80, 0, 1.25), rub_rotation),
                    (48, (.80, 0, 1.25), rub_rotation),
                    (52, (.80, 0, contact), rub_rotation),
                    (59, (1.50, 0, contact), rub_rotation),
                    (65, (.80, 0, contact), rub_rotation),
                    (69, (.80, 0, 1.25), rub_rotation),
                    (76, resting, (0, 0, 0))])
    bottle = oil_bottle((2.65, 1.25, .183))
    # Mouth coordinates determine the pour; oil lands on the same growing trace.
    tilt = -2.0
    neck_offset = math.sin(tilt)*1.28
    rests = (2.65, 1.25, .183)
    poses = [(1, rests, (0, 0, 0)), (68, rests, (0, 0, 0))]
    for x, first, last in [(-1.15, 80, 94), (1.15, 108, 122)]:
        for frame in [first-5, first, last, last+4]:
            fraction = max(0, min(1, (frame-first)/(last-first)))
            hit_x = x-.60+fraction*1.20
            angle = -.6 if frame in [first-5, last+4] else tilt
            poses.append((frame, (hit_x-neck_offset, 0, 1.90), (0, angle, 0)))
    poses.extend([(132, rests, (0, 0, 0)), (192, rests, (0, 0, 0))])
    animate(bottle, poses)
    for x, first, last in [(-1.15, 80, 94), (1.15, 108, 122)]:
        def landing(frame, centre=x, a=first, b=last):
            fraction = (frame-a)/(b-a)
            return (centre-.60+fraction*1.20, 0, top+.003)
        pouring_stream(bottle, first, last, landing)
        trace = art.curve('Huile déposée sur la mie', [(x-.60+j*.06, 0, top+.005)
                                                     for j in range(21)], .014, oil)
        reveal_curve(trace, first, last-first)
        for j in range(3):
            drop(mozzarella((0, 0, 0)), (x+(j-1)*.50, 0, top+.009),
                 139+(x>0)*15+j*5, 14)
    return (0, 0, .52), 8.0


def bowl_floor(radius):
    return .22 + max(0, radius-.65)*(.53/.77)


def stir_angle(frame):
    t = max(0, min(1, (frame-72)/96))
    return TAU*1.25*(3*t*t-2*t*t*t)


def seasoning():
    art.ringmesh('Bol de céramique ouvert', [(.01, .01, .07), (.75, .65, .08),
                                           (1.50, 1.30, .73), (1.78, 1.54, 1.12),
                                           (1.70, 1.46, 1.15), (1.42, 1.23, .75),
                                           (.65, .55, .22), (.01, .01, .22)], art.cream)
    ellipse('Liseré du bol', 1.75, 1.50, 1.14, art.ink, radius=.008)
    layout = [(0, 0, 0)]
    layout += [(.52, j*TAU/6+math.pi/6, 0) for j in range(6)]
    layout += [(1.04, j*TAU/12, 0) for j in range(12)]
    layout += [(.34, j*TAU/4, .30) for j in range(4)]
    layout += [(0, 0, .233)]
    for radius, base, layer in layout:
        obj = tomato((0, 0, 0))
        poses = []
        for frame in [1, 72, *range(76, 169, 4), 192]:
            angle = stir_angle(frame)
            rotation = (0, 0, angle)
            height = bowl_floor(radius+.23)+layer-mesh_bottom(obj, rotation)+.003
            poses.append((frame, (radius*math.cos(base+angle), radius*math.sin(base+angle)*.82,
                                  height), rotation))
        animate(obj, poses)
    for j in range(4):
        base = j*TAU/4
        obj = leaf((0, 0, 0))
        position = (.34*math.cos(base), .34*math.sin(base)*.82, .758)
        drop(obj, position, 31+j*5, 16)
        poses = [(72, position, (0, 0, base))]
        for frame in [*range(76, 169, 4), 192]:
            angle = stir_angle(frame)
            poses.append((frame, (.34*math.cos(base+angle), .34*math.sin(base+angle)*.82,
                                  .758), (0, 0, base+angle)))
        animate(obj, poses)
    bottle = oil_bottle((-2.10, -.3, .06))
    tilt = -2.0
    pour_position = (-math.sin(tilt)*1.28, 0, 1.9)
    animate(bottle, [(1, (-2.10, -.3, .06), (0, 0, 0)),
                     (12, pour_position, (0, tilt, 0)),
                     (25, pour_position, (0, tilt, 0)),
                     (31, (pour_position[0], 0, 2.0), (0, -.5, 0)),
                     (42, (-2.10, -.3, .06), (0, 0, 0))])
    pouring_stream(bottle, 14, 25, lambda frame: (0, 0, .687))
    # Salt and pepper land on a tomato and follow it while mixing.
    for j in range(16):
        size = (.014, .014, .014) if j%3 else (.018, .016, .015)
        grain = sphere('Sel' if j%3 else 'Poivre', (0, 0, 0), size,
                       art.cheese if j%3 else art.ink)
        x, y = random.uniform(-.10, .10), random.uniform(-.09, .09)
        height = .686+size[2]+.002
        drop(grain, (x, y, height), 52+j//4, 12)
        poses = [(72, (x, y, height), (0, 0, 0))]
        for frame in [*range(76, 169, 4), 192]:
            a = stir_angle(frame)
            poses.append((frame, (x*math.cos(a)-y*math.sin(a), x*math.sin(a)+y*math.cos(a), height),
                          (0, 0, a)))
        animate(grain, poses)
    spoon = art.empty('Cuillère en bois')
    art.ringmesh('Cuilleron', [(.12, .17, -.04), (.17, .23, 0),
                             (.16, .22, .05), (.11, .16, .07)], wood, spoon)
    art.curve('Manche arrondi', [(0, .18, .02), (0, .95, .035), (0, 1.8, .06)], .052, wood, spoon)
    rest = (2.14, -.72, .115)
    path = [(1, rest, (0, 0, -.35)), (63, rest, (0, 0, -.35)),
            (68, (1.70, -.35, 1.65), (.95, 0, .25))]
    for frame in [72, *range(76, 169, 4)]:
        a = stir_angle(frame)+math.pi/12
        path.append((frame, (.80*math.cos(a), .80*math.sin(a)*.82, .90), (.95, 0, a)))
    path.extend([(178, (1.75, -.35, 1.65), (.95, 0, -.35)),
                 (189, rest, (0, 0, -.35)), (192, rest, (0, 0, -.35))])
    animate(spoon, path)
    return (0, 0, .70), 7.8


def plating():
    art.ringmesh('Assiette tournée', [(2.9, 2.1, .02), (3.0, 2.2, .10),
                                     (2.92, 2.12, .22), (2.6, 1.85, .12),
                                     (2.3, 1.6, .105)], art.cream)
    for rx, ry, z in [(2.92, 2.12, .22), (2.6, 1.85, .125)]:
        ellipse('Liseré de l’assiette', rx, ry, z, art.ink, radius=.006)
    for side in range(2):
        x = -1.05 if side==0 else 1.05
        y = .12 if side==0 else -.12
        loaf = bread('Tartine déjà gratinée', (x, y, .13))
        for j in range(3):
            mozzarella(((j-1)*.52, 0, .345), loaf, melted=True)
        for row in range(3):
            for col in range(4):
                obj = tomato((0, 0, 0))
                obj.scale = (.76, .76, .76)
                position = (x+(col-1.5)*.37, y+(row-1)*.23, .13+.345+.05+.115*.76)
                drop(obj, position, 9+side*24+row*9+col*3, 17)
        for j in range(2):
            obj = leaf((0, 0, 0))
            drop(obj, (x+(j-.5)*.45, y, .13+.345+.05+.23*.76+.006),
                 101+side*7+j*6, 17)
    return (0, 0, .5), 8.2


def setup(name):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    random.seed(19)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.eevee.taa_render_samples = 32
    scene.render.resolution_x = 840
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.fps = 24
    scene.frame_set(1)
    scene.frame_start = 1
    scene.frame_end = SCENES[name]
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = True
    scene.view_settings.view_transform = 'Standard'
    scene.world.color = (.8, .8, .8)
    return scene


selected = sys.argv[sys.argv.index('--scene')+1] if '--scene' in sys.argv else None
if selected and selected not in SCENES:
    raise SystemExit('Unknown scene: '+selected)
for name in SCENES:
    if selected and selected != name:
        continue
    scene = setup(name)
    target, scale = {'toast-preheat': lambda: oven(False), 'toast-baking': lambda: oven(True),
                     'toast-cutting': cutting, 'toast-building': building,
                     'toast-seasoning': seasoning, 'toast-plating': plating}[name]()
    for xyz, energy, size in [((-3, -4, 7), 650, 6), ((4, 2, 5), 230, 5)]:
        bpy.ops.object.light_add(type='AREA', location=xyz)
        bpy.context.object.data.energy = energy
        bpy.context.object.data.size = size
    bpy.ops.object.camera_add(location=Vector(target)+Vector((5, -7, 7)))
    cam = bpy.context.object
    cam.rotation_euler = (Vector(target)-cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = scale
    scene.camera = cam
    folder = OUT/name
    folder.mkdir(parents=True, exist_ok=True)
    scene.frame_set(1)
    scene.render.filepath = str(folder/'frame_')
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/(name+'.blend')))
    for frame, label in [(1, 'start'), (scene.frame_end, 'poster')]:
        scene.frame_set(frame)
        scene.render.filepath = str(folder/(label+'.png'))
        bpy.ops.render.render(write_still=True)
    if '--preview-only' in sys.argv:
        for frame in [scene.frame_end//4, scene.frame_end//2, scene.frame_end*3//4]:
            scene.frame_set(frame)
            scene.render.filepath = str(folder/(f'pose-{frame:03}.png'))
            bpy.ops.render.render(write_still=True)
    else:
        for old_frame in folder.glob('frame_[0-9][0-9][0-9][0-9].png'):
            old_frame.unlink()
        scene.render.filepath = str(folder/'frame_')
        bpy.ops.render.render(animation=True)
