"""Six restrained, local Blender illustrations for lemon pasta.

blender -b --threads 4 --python-exit-code 1 --python scripts/animation/lemon_pasta_scenes.py -- /tmp/PetitChef-lemon --preview-only
Omit --preview-only to render; --scene pasta-zest selects a single sequence.
"""
import bpy
import math
import random
import sys
from pathlib import Path
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import toast_scene_tools as art

OUT = Path(sys.argv[sys.argv.index('--') + 1])
SCENES = {'pasta-water': 144, 'pasta-zest': 192, 'pasta-boil': 144,
          'pasta-sauce': 192, 'pasta-toss': 192, 'pasta-serve': 144}
TAU = math.tau
ivory = art.material('Ivoire chaud', (.93, .92, .85))
metal = art.material('Acier satiné', (.65, .71, .69))
lemonmat = art.material('Jaune citron', (.93, .73, .20))
flesh = art.material('Pulpe claire', (.97, .87, .48))
pasta = art.material('Pâtes dorées', (.88, .70, .34))
sauce = art.material('Sauce citronnée', (.95, .87, .62))
wood = art.material('Bois clair', (.71, .52, .31))
water = art.material('Eau claire', (.76, .86, .84))
steam = art.material('Vapeur légère', (.80, .84, .81))


def ring(name, rx, ry, z, mat=art.ink, parent=None, radius=.009):
    return art.curve(name, [(rx*math.cos(i*TAU/80), ry*math.sin(i*TAU/80), z)
                          for i in range(81)], radius, mat, parent)


def mesh(name, profile, mat, parent=None):
    return art.ringmesh(name, profile, mat, parent)


def cube(name, loc, size, mat, parent=None, bevel=.05):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new('Coins doux', 'BEVEL'); mod.width = bevel; mod.segments = 3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    art.finish(obj, mat)
    obj.parent = parent; obj.location = loc
    return obj


def sphere(name, loc, size, mat, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12)
    obj=bpy.context.object; obj.name=name;obj.scale=size
    art.finish(obj,mat);obj.parent=parent;obj.location=loc
    return obj


def pose(obj, frames):
    art.keys(obj, frames)


def scale_keys(obj, frames):
    base = obj.scale.copy()
    for frame, factor in frames:
        obj.scale = base * factor
        obj.keyframe_insert(data_path='scale', frame=frame)
    if obj.animation_data:
        for layer in obj.animation_data.action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for key in fc.keyframe_points:
                            key.handle_left_type=key.handle_right_type='AUTO_CLAMPED'


def pot():
    root=art.empty('Casserole')
    mesh('Corps de la casserole', [(1.16,1.16,.04),(1.27,1.27,.13),(1.36,1.36,1.10),
                                  (1.32,1.32,1.16),(1.25,1.25,1.09),(1.16,1.16,.20)], ivory, root)
    ring('Bord graphite',1.34,1.34,1.125,parent=root,radius=.014)
    ring('Base fine',1.23,1.23,.10,parent=root,radius=.01)
    for side in [-1,1]:
        art.curve('Poignée',[(side*1.29,-.26,.90),(side*1.69,-.26,.90),
                            (side*1.75,.26,.90),(side*1.29,.26,.90)],.055,metal,root)
        art.curve('Contour poignée',[(side*1.34,-.27,.94),(side*1.72,-.27,.94),
                                   (side*1.77,.27,.94)],.008,art.ink,root)
    mesh('Eau',[(1.20,1.20,.81),(1.20,1.20,.83)],water,root)
    return root


def pan():
    root=art.empty('Poêle')
    mesh('Poêle ivoire',[(1.66,1.66,.05),(1.76,1.76,.12),(1.90,1.90,.47),
                        (1.86,1.86,.53),(1.73,1.73,.44),(1.64,1.64,.17)],ivory,root)
    ring('Bord de la poêle',1.87,1.87,.49,parent=root,radius=.013)
    handle=cube('Manche en bois',(2.53,.07,.40),(1.53,.25,.18),wood,root,bevel=.07)
    art.curve('Contour du manche',[(1.90,-.055,.50),(3.17,-.055,.50),(3.27,.07,.50),
                                 (3.17,.195,.50),(1.9,.195,.50)],.009,art.ink,root)
    return root


def lemon(parent=None, half=False):
    root=art.empty('Demi-citron' if half else 'Citron');root.parent=parent
    if not half:
        sphere('Peau du citron',(0,0,0),(.48,.35,.36),lemonmat,root)
        for side in [-1,1]: sphere('Pointe', (side*.45,0,0),(.09,.095,.095),lemonmat,root)
        # Quiet pencil marks retain the toast's handmade character.
        for j in range(7):
            a=j*.47
            art.curve('Trait de peau',[(-.26,.27*math.sin(a),.29*math.cos(a)),
                                       (-.13,.32*math.sin(a),.33*math.cos(a)),
                                       (.12,.32*math.sin(a),.33*math.cos(a))],.003,wood,root)
    else:
        mesh('Écorce',[(.0,.0,-.28),(.23,.23,-.23),(.38,.38,-.07),(.40,.40,0)],lemonmat,root)
        mesh('Chair',[(.355,.355,.006),(.355,.355,.016)],flesh,root)
        ring('Contour du citron',.39,.39,.014,lemonmat,root,.012)
        for j in range(8):
            a=j*TAU/8
            art.curve('Quartier',[(0,0,.026),(.32*math.cos(a),.32*math.sin(a),.026)],.009,ivory,root)
    return root


def leaf(loc, rotation=0):
    obj=art.empty('Basilic')
    verts=[(0,0,.02)]
    for j in range(24):
        a=j*TAU/24
        verts.append((.35*math.cos(a),.18*math.sin(a),.035*math.sin(a)**2))
    faces=[(0,j+1,(j+1)%24+1) for j in range(24)]
    data=bpy.data.meshes.new('Feuille');data.from_pydata(verts,[],faces);data.update()
    blade=bpy.data.objects.new('Feuille courbe',data);bpy.context.collection.objects.link(blade)
    art.finish(blade,art.green);blade.parent=obj
    art.curve('Nervure',[(-.32,0,.034),(0,0,.04),(.32,0,.034)],.006,art.veinmat,obj)
    obj.location=loc;obj.rotation_euler.z=rotation
    return obj


def noodles(parent, radius=1.30, height=.28, count=22):
    """Curved individual strands, with irregular ends and a low nest silhouette."""
    root=art.empty('Spaghetti');root.parent=parent
    for j in range(count):
        points=[]
        phase=j*2.39996
        for k in range(65):
            t=k/64
            a=phase+t*TAU*1.8
            r=radius*(.20+.70*math.sin(math.pi*t))*(.85+.09*math.sin(j))
            z=height+.055*(j%4)+.065*math.sin(a*2+j)+.08*math.sin(math.pi*t)
            points.append((r*math.cos(a),r*.81*math.sin(a),z))
        art.curve('Spaghetti courbé',points,.022,pasta,root)
        # A thin darker edge gives readable overlap, without outlining each tube.
        if j%4==0: art.curve('Trait sur les pâtes',[(x,y,z+.020) for x,y,z in points[::2]],.0025,wood,root)
    return root


def vapor(parent, z, radius=.7, start=1):
    for j in range(3):
        obj=art.curve('Vapeur',[(.055*math.sin(k*.6+j),0,k*.055) for k in range(14)],.008,steam,parent)
        x=(j-1)*radius
        pose(obj,[(1,(x,.25,z),(0,0,0)),(start,(x,.25,z),(0,0,0)),
                  (start+56,(x+.08,.25,z+.35),(0,0,.12)),(SCENES[NAME],(x+.1,.25,z+.45),(0,0,.16))])
        scale_keys(obj,[(1,0),(start,0),(start+24,1),(SCENES[NAME],.75)])


def water_scene():
    root=pot()
    # Rings and small bubbles grow toward a simmer, then settle in a readable pose.
    for j in range(9):
        a=j*2.399; r=.2+.10*(j%6)
        obj=ring('Bulle',.045,.045,.845,ivory,root,.008)
        obj.location=(r*math.cos(a),r*math.sin(a),0)
        scale_keys(obj,[(1,0),(25+j*6,0),(46+j*6,1.5),(110,1),(144,1)])
    vapor(root,1.02,start=35)
    # The subtle halo below the pot is a heat cue, not a timer.
    ring('Chaleur',1.17,1.17,.015,lemonmat,root,.013)
    return (0,0,.85),5.0


def zest_scene():
    board=cube('Planche',(0,0,-.025),(3.55,2.2,.08),wood,bevel=.10)
    grater=art.empty('Râpe fine')
    grater.rotation_euler=(0,-.26,0)
    cube('Acier de la râpe',(0,0,.54),(1.32,.58,.07),metal,grater,bevel=.045)
    cube('Poignée',(.93,0,.54),(.57,.26,.16),ivory,grater,bevel=.08)
    art.curve('Contour de râpe',[(-.66,-.29,.585),(.66,-.29,.585),(.66,.29,.585),(-.66,.29,.585),(-.66,-.29,.585)],.007,art.ink,grater)
    for x in [-.46,-.23,0,.23,.46]:
        for y in [-.17,0,.17]:
            art.curve('Dents de râpe',[(x-.04,y-.025,.592),(x,y+.027,.61),(x+.04,y-.025,.592)],.007,art.ink,grater)
    fruit=lemon()
    # The peel touches the raised teeth; each pass ends before the next starts.
    poses=[]
    for f,x in [(1,-.40),(18,-.40),(42,.34),(55,-.40),(78,.34),(91,-.40),(114,.34),(136,-.40),(154,.34)]:
        poses.append((f,(x,-.025,.91+x*.27),(0,-.26,.12)))
    poses.extend([(171,(-.90,.35,.39),(0,0,-.15)),(192,(-.90,.35,.39),(0,0,-.15))]);pose(fruit,poses)
    for j in range(18):
        x=-.43+(j%6)*.13;y=-.27-(j//6)*.095
        shaving=art.curve('Zeste',[(0,0,0),(.045,.028,.012),(.08,.004,.019)],.01,lemonmat)
        end=(x,y,.053)
        begin=28+j*6
        scale_keys(shaving,[(1,0),(begin,0),(begin+2,1)])
        pose(shaving,[(1,(x,0,.48),(0,0,j*.2)),(begin,(x,0,.48),(0,0,j*.2)),
                       (begin+15,end,(0,0,j*.2)),(192,end,(0,0,j*.2))])
    half=lemon(half=True);half.location=(1.05,-.60,.34)
    return (0,0,.55),5.3


def boil_scene():
    root=pot()
    bunch=art.empty('Spaghetti secs')
    for j in range(15):
        x=(j-7)*.055
        art.curve('Spaghetti sec',[(x,-.10,.02),(x+.025,-.09,.60),
                                 (x+.10*math.sin(j),-.04,1.75)],.015,pasta,bunch)
    pose(bunch,[(1,(0,0,2.05),(0,-.24,0)),(18,(0,0,2.05),(0,-.24,0)),
                (72,(0,0,.55),(0,-.09,0)),(96,(0,0,.10),(0,0,0))])
    scale_keys(bunch,[(1,1),(74,1),(105,0)])
    cooked=noodles(root,radius=.94,height=.78,count=15)
    scale_keys(cooked,[(1,0),(66,0),(103,1),(144,1)])
    vapor(root,1.18,start=56)
    return (0,0,1.20),5.7


def spoon(parent=None):
    root=art.empty('Cuillère');root.parent=parent
    mesh('Cuilleron',[(.15,.22,.0),(.21,.29,.07),(.21,.29,.11),(.15,.22,.07)],ivory,root)
    cube('Manche',(0,.69,.08),(.13,1.06,.09),wood,root,bevel=.04)
    return root


def sauce_scene():
    root=pan()
    butter=cube('Beurre',(0,0,.63),(.60,.45,.31),flesh,bevel=.055)
    pose(butter,[(1,(0,0,1.38),(0,0,0)),(18,(0,0,1.38),(0,0,0)),
                 (38,(0,0,.34),(0,0,.16)),(80,(0,0,.26),(0,0,.16))])
    scale_keys(butter,[(1,1),(40,1),(100,0)])
    pool=mesh('Beurre fondu',[(1.47,1.47,.20),(1.47,1.47,.22)],sauce,root)
    scale_keys(pool,[(1,0),(40,.05),(100,1),(192,1)])
    for j in range(17):
        a=j*2.399;r=.20+.048*j
        p=(r*math.cos(a),r*math.sin(a),.236)
        obj=art.curve('Zeste dans la sauce',[(0,0,0),(.045,.02,.01),(.09,0,.0)],.009,lemonmat,root)
        begin=80+j*2
        scale_keys(obj,[(1,0),(begin,0),(begin+1,1)])
        pose(obj,[(1,(p[0],p[1],1.15),(0,0,a)),(begin,(p[0],p[1],1.15),(0,0,a)),
                  (begin+17,p,(0,0,a)),(192,p,(0,0,a))])
    ladle=spoon()
    pose(ladle,[(1,(-.8,.8,1.55),(0,0,0)),(118,(-.8,.8,1.55),(0,0,0)),
                (139,(-.55,0,1.10),(.63,0,.12)),(160,(-.55,0,1.10),(.63,0,.12)),
                (182,(-1.60,.85,.26),(0,0,-.25)),(192,(-1.60,.85,.26),(0,0,-.25))])
    scale_keys(ladle,[(1,0),(118,0),(132,1),(192,1)])
    # The stream's first point follows the tilted spoon lip at every frame.
    stream=art.curve('Eau de cuisson',[(0,0,0)]*9,.014,water)
    for f in range(140,160):
        bpy.context.scene.frame_set(f)
        mouth=ladle.matrix_world@Vector((0,-.20,.11))
        landing=Vector((-.48,0,.245))
        for i,p in enumerate(stream.data.splines[0].points):
            t=i/8; co=mouth.lerp(landing,t);co.x+=.045*math.sin(math.pi*t)
            p.co=(*co,1);p.keyframe_insert(data_path='co',frame=f)
    stream.hide_render=True;stream.keyframe_insert(data_path='hide_render',frame=1)
    stream.hide_render=False;stream.keyframe_insert(data_path='hide_render',frame=140)
    stream.hide_render=True;stream.keyframe_insert(data_path='hide_render',frame=160)
    return (.55,0,.56),6.8


def sprinkle(root, start, end, height=.60):
    for j in range(32):
        a=j*2.399;r=1.0*math.sqrt((j+.5)/32)
        landing=(r*math.cos(a),r*.8*math.sin(a),height+.04*(j%3))
        flake=cube('Parmesan', (0,0,0),(.06,.025,.014),ivory,root,bevel=.008)
        begin=start+int(j*(end-start)/32)
        scale_keys(flake,[(1,0),(begin,0),(begin+1,1)])
        pose(flake,[(1,(landing[0],landing[1],1.7),(0,0,a)),
                    (begin,(landing[0],landing[1],1.7),(0,0,a)),
                    (begin+14,landing,(.1,0,a)),(SCENES[NAME],landing,(.1,0,a))])


def toss_scene():
    root=pan()
    mesh('Sauce',[(1.57,1.57,.20),(1.57,1.57,.23)],sauce,root)
    nest=noodles(root)
    sprinkle(nest,22,64)
    fruit=lemon(half=True)
    pose(fruit,[(1,(-1.06,-.16,1.65),(0,.24,0)),(72,(-1.06,-.16,1.65),(0,.24,0)),
               (100,(-1.06,-.16,1.36),(0,.52,0)),(116,(-1.06,-.16,1.65),(0,.24,0)),
               (140,(-2.12,-.58,.28),(0,0,0)),(192,(-2.12,-.58,.28),(0,0,0))])
    for j in range(6):
        drop=sphere('Jus de citron',(0,0,0),(.025,.025,.055),flesh)
        begin=79+j*4
        scale_keys(drop,[(1,0),(begin,0),(begin+1,1),(begin+14,1),(begin+15,0)])
        pose(drop,[(1,(-.94,-.14,1.15),(0,0,0)),(begin,(-.94,-.14,1.15),(0,0,0)),
                   (begin+14,(-.90,-.14,.40),(0,0,0))])
    utensil=spoon()
    # A smooth arc around the pan: ingredients rotate as a single coated nest.
    path=[(1,(.95,.7,1.3),(.9,0,-.3)),(120,(.95,.7,1.3),(.9,0,-.3))]
    for f in range(128,172,4):
        t=(f-128)/44; a=t*TAU
        path.append((f,(.95*math.cos(a),.65*math.sin(a),.58),(.70,.15,a+.2)))
    path.extend([(184,(.55,1.45,.38),(0,0,-.4)),(192,(.55,1.45,.38),(0,0,-.4))]);pose(utensil,path)
    pose(nest,[(1,(0,0,0),(0,0,0)),(124,(0,0,0),(0,0,0)),
               (148,(.04,.03,.03),(0,0,.20)),(172,(0,0,0),(0,0,.42)),(192,(0,0,0),(0,0,.42))])
    # A cup outside the pan is the visual reminder to save cooking water.
    cup=mesh('Tasse d’eau',[(.35,.35,.0),(.40,.40,.08),(.42,.42,.61),(.36,.36,.61),(.32,.32,.12)],ivory)
    cup.location=(-2.15,.75,0)
    ring('Bord tasse',.40,.40,.61,parent=cup)
    mesh('Eau réservée',[(.345,.345,.44),(.345,.345,.46)],water,cup)
    return (.2,0,.65),7.6


def serve_scene():
    plate=mesh('Assiette',[(1.95,1.70,.02),(2.10,1.82,.07),(2.20,1.90,.17),
                          (2.03,1.76,.22),(1.62,1.40,.11)],ivory)
    ring('Liseré assiette',2.10,1.82,.18,parent=plate,radius=.009)
    ring('Creux assiette',1.63,1.40,.115,metal,plate,.006)
    nest=noodles(plate,radius=1.16,height=.17,count=26)
    sprinkle(nest,14,52,height=.44)
    for j in range(3):
        landing=((j-1)*.30,.05+j*.04,.57+j*.015)
        obj=leaf(landing,rotation=j*.85-.6)
        pose(obj,[(1,(landing[0]-.25,landing[1],1.70+j*.12),(0,0,j*.85-.6)),
                  (62+j*12,(landing[0]-.25,landing[1],1.70+j*.12),(0,0,j*.85-.6)),
                  (88+j*12,landing,(0,0,j*.85-.6)),(144,landing,(0,0,j*.85-.6))])
        scale_keys(obj,[(1,0),(62+j*12,0),(63+j*12,1),(144,1)])
    half=lemon(half=True);half.location=(-1.52,.34,.34);half.scale=(.75,.75,.75)
    return (0,0,.5),5.8


def setup(name):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    random.seed(27)
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE'
    scene.eevee.taa_render_samples=16
    scene.render.resolution_x=840;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.render.fps=24;scene.frame_start=1;scene.frame_end=SCENES[name];scene.frame_set(1)
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=True;scene.view_settings.view_transform='Standard';scene.world.color=(.8,.8,.8)
    return scene


selected=sys.argv[sys.argv.index('--scene')+1] if '--scene' in sys.argv else None
if selected and selected not in SCENES: raise SystemExit('Unknown scene: '+selected)
for NAME in SCENES:
    if selected and NAME!=selected:continue
    scene=setup(NAME)
    target, scale={'pasta-water':water_scene,'pasta-zest':zest_scene,'pasta-boil':boil_scene,
                   'pasta-sauce':sauce_scene,'pasta-toss':toss_scene,'pasta-serve':serve_scene}[NAME]()
    for xyz,energy,size in [((-3,-4,7),650,6),((4,2,5),230,5)]:
        bpy.ops.object.light_add(type='AREA',location=xyz);bpy.context.object.data.energy=energy;bpy.context.object.data.size=size
    bpy.ops.object.camera_add(location=Vector(target)+Vector((3,-6,6)))
    cam=bpy.context.object;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=scale;scene.camera=cam
    folder=OUT/NAME;folder.mkdir(parents=True,exist_ok=True)
    scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(folder/(NAME+'.blend')))
    for frame,label in [(1,'start'),(SCENES[NAME],'poster')]:
        scene.frame_set(frame);scene.render.filepath=str(folder/(label+'.png'));bpy.ops.render.render(write_still=True)
    if '--preview-only' in sys.argv:
        for frame in [SCENES[NAME]//4,SCENES[NAME]//2,SCENES[NAME]*3//4]:
            scene.frame_set(frame);scene.render.filepath=str(folder/(f'pose-{frame:03}.png'));bpy.ops.render.render(write_still=True)
    else:
        scene.render.filepath=str(folder/'frame_');bpy.ops.render.render(animation=True)
