"""Reproducible, authored 3D pilot. Blender 5.2; no external models.
Render: blender -b --python scripts/animation/toast_pilot.py -- /tmp/toast-pilot
Frames remain outside the repository; source .blend and preview are reviewable.
"""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector
random.seed(19)
out=Path(sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else '/tmp/toast-pilot')
out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=840; scene.render.resolution_y=640; scene.render.resolution_percentage=100
scene.render.fps=24; scene.frame_start=1; scene.frame_end=144
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=True
scene.render.filepath=str(out/'frame_')
scene.view_settings.view_transform='Standard'
scene.world.color=(0.8,0.8,0.8)

def material(name,color,roughness=0.8):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 nodes=m.node_tree.nodes; nodes.clear()
 output=nodes.new('ShaderNodeOutputMaterial')
 diffuse=nodes.new('ShaderNodeBsdfDiffuse'); diffuse.inputs['Color'].default_value=(*color,1)
 # Two restrained light bands produce illustrated form rather than plastic speculars.
 rgb=nodes.new('ShaderNodeShaderToRGB'); ramp=nodes.new('ShaderNodeValToRGB')
 ramp.color_ramp.interpolation='EASE'
 ramp.color_ramp.elements[0].position=.18; ramp.color_ramp.elements[0].color=tuple(c*.58 for c in color)+(1,)
 ramp.color_ramp.elements[1].position=.78; ramp.color_ramp.elements[1].color=tuple(min(1,c*1.1+.04) for c in color)+(1,)
 emit=nodes.new('ShaderNodeEmission')
 links=m.node_tree.links; links.new(diffuse.outputs[0],rgb.inputs[0]);links.new(rgb.outputs[0],ramp.inputs[0]);links.new(ramp.outputs[0],emit.inputs[0]);links.new(emit.outputs[0],output.inputs[0])
 return m
ink=material('Graphite vert',(.12,.17,.14)); crust=material('Croûte dorée',(.62,.37,.17)); crumb=material('Mie ivoire',(.91,.79,.58))
cream=material('Porcelaine',(.94,.93,.86)); cheese=material('Mozzarella',(.98,.96,.84)); red=material('Tomate chair',(.83,.24,.13)); seedmat=material('Graines',(.93,.73,.39))
green=material('Basilic',(.31,.49,.26)); veinmat=material('Nervures',(.17,.29,.16)); poremat=material('Alvéoles',(.59,.42,.25))

def finish(obj,mat,outline=False):
 obj.data.materials.append(mat)
 for f in obj.data.polygons: f.use_smooth=True
 if outline:
  # Real curves on the twelve edges; rear edges are occluded by the solid food.
  # No inverted shell, which would cover the food with some Eevee materials.
  x,y,z=(d/2 for d in obj.dimensions)
  for axis in range(3):
   others=[i for i in range(3) if i!=axis]
   for sa in [-1,1]:
    for sb in [-1,1]:
     p0=[0,0,0];p1=[0,0,0];dims=[x,y,z]
     p0[axis]=-dims[axis]+.028;p1[axis]=dims[axis]-.028
     p0[others[0]]=p1[others[0]]=sa*(dims[others[0]]-.009)
     p0[others[1]]=p1[others[1]]=sb*(dims[others[1]]-.009)
     curve('Arête de tomate',[tuple(p0),tuple(p1)],.0035,ink,obj)
 return obj

def curve(name,points,radius,mat,parent=None):
 data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=radius;data.bevel_resolution=2
 spline=data.splines.new('POLY');spline.points.add(len(points)-1)
 for v,co in zip(spline.points,points):v.co=(*co,1)
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.data.materials.append(mat)
 if parent:obj.parent=parent
 return obj

def ringmesh(name,profile,mat,parent=None,organic=0):
 n=72;verts=[]
 for rx,ry,z in profile:
  for j in range(n):
   a=j*2*math.pi/n;r=1+organic*(math.sin(a*3)+.6*math.cos(a*7))
   verts.append((rx*r*math.cos(a),ry*r*math.sin(a),z))
 faces=[tuple(range(n-1,-1,-1))]
 for i in range(len(profile)-1):
  for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
 faces.append(tuple((len(profile)-1)*n+j for j in range(n)))
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
 finish(obj,mat)
 if parent:obj.parent=parent
 return obj

def empty(name):
 obj=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(obj);return obj

def keys(obj,frames):
 for f,loc,rot in frames:
  obj.location=loc;obj.rotation_euler=rot;obj.keyframe_insert(data_path='location',frame=f);obj.keyframe_insert(data_path='rotation_euler',frame=f)
 # Clamped Bezier handles avoid bounce through the bread or board.
 if obj.animation_data:
  action=obj.animation_data.action
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for fc in bag.fcurves:
      for k in fc.keyframe_points:k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'

def place(obj,xyz,start,duration=15,tilt=.12):
 x,y,z=xyz
 # Hidden until approach; final position is the contact plane.
 for frame,scale in [(1,0),(max(1,start-1),0),(start+4,1),(144,1)]:
  obj.scale=(scale,scale,scale);obj.keyframe_insert(data_path='scale',frame=frame)
 keys(obj,[(1,(x-.35,y+.2,z+3.5),(tilt,-tilt,.3)),(start,(x-.35,y+.2,z+3.5),(tilt,-tilt,.3)),(start+duration,(x,y,z),(0,0,0)),(144,(x,y,z),(0,0,0))])

plate=ringmesh('Assiette tournée',[(2.9,2.1,.02),(3.0,2.2,.10),(2.92,2.12,.22),(2.6,1.85,.12),(2.3,1.6,.105)],cream)
for rx,ry,z in [(2.92,2.12,.22),(2.6,1.85,.125)]:
 curve('Liseré de l’assiette',[(rx*math.cos(a),ry*math.sin(a),z) for a in [j*2*math.pi/144 for j in range(145)]],.006,ink)

for side in range(2):
 root=empty('Tartine '+str(side+1));x=-1.05 if side==0 else 1.05;y=.12 if side==0 else -.12
 bread=ringmesh('Pain de campagne',[(1.08,.73,0),(1.11,.75,.08),(1.06,.70,.30),(.98,.65,.33)],crust,root,.025)
 face=ringmesh('Mie',[(.95,.625,.329),(.96,.63,.338)],crumb,root,.025)
 # Designed pore distribution avoids a noisy uniform dotted texture.
 for i in range(44):
  a=random.uniform(0,2*math.pi);r=math.sqrt(random.random())*.88
  px=math.cos(a)*r;py=math.sin(a)*r*.63
  bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=1,location=(px,py,.342))
  pore=bpy.context.object;pore.name='Alvéole';pore.scale=(random.uniform(.015,.04),random.uniform(.012,.028),.006);finish(pore,poremat);pore.parent=root
 outline=[(1.07*(1+.025*(math.sin(a*3)+.6*math.cos(a*7)))*math.cos(a),.705*(1+.025*(math.sin(a*3)+.6*math.cos(a*7)))*math.sin(a),.3) for a in [j*2*math.pi/144 for j in range(145)]]
 curve('Croûte dessinée',outline,.009,ink,root)
 for j in range(14):
  a=math.pi+ j*.16
  curve('Hachure de croûte',[(1.105*math.cos(a),.745*math.sin(a),.09),(1.085*math.cos(a+.045),.72*math.sin(a+.045),.24)],.003,ink,root)
 place(root,(x,y,.13),4+side*18,17)
 for j in range(3):
  cx=x+(j-1)*.52;cy=y
  m=ringmesh('Tranche de mozzarella',[(.36,.29,0),(.4,.31,.035),(.38,.29,.075),(.32,.25,.085)],cheese,organic=.045)
  border=curve('Contour du fromage',[(.38*math.cos(a),.29*math.sin(a),.075) for a in [k*2*math.pi/72 for k in range(73)]],.006,ink,m)
  place(m,(cx,cy,.49),44+side*12+j*4,14,.1)
 # Small irregular tomato blocks, bevelled surfaces and genuine depth.
 for j in range(12):
  px=x+random.uniform(-.78,.78);py=y+random.uniform(-.34,.34)
  bpy.ops.mesh.primitive_cube_add(size=1)
  obj=bpy.context.object;obj.name='Dés de tomate';obj.scale=(.21+random.random()*.06,.18+random.random()*.05,.17+random.random()*.03)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bevel=obj.modifiers.new('Bords de chair','BEVEL');bevel.width=.035;bevel.segments=3
  bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=bevel.name)
  finish(obj,red,outline=True)
  bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=1)
  seed=bpy.context.object;seed.name='Graine de tomate';seed.scale=(.022,.04,.006);seed.location=(0,0,.1);finish(seed,seedmat);seed.parent=obj
  place(obj,(px,py,.64),72+side*10+j,12,.2)
 # Curved basil mesh, a raised spine, and seven paired veins.
 for j in range(2):
  verts=[];faces=[];n=16
  for k in range(n+1):
   t=k/n;long=(t-.5)*.72;w=math.sin(math.pi*t)*.19
   verts.extend([(-w,long,.025*math.sin(math.pi*t)),(0,long,.075*math.sin(math.pi*t)),(w,long,.025*math.sin(math.pi*t))])
  for k in range(n):
   for c in range(2):faces.append((k*3+c,k*3+c+1,(k+1)*3+c+1,(k+1)*3+c))
  data=bpy.data.meshes.new('Feuille');data.from_pydata(verts,[],faces);data.update()
  obj=bpy.data.objects.new('Basilic courbé',data);bpy.context.collection.objects.link(obj);finish(obj,green)
  solid=obj.modifiers.new('Épaisseur du basilic','SOLIDIFY');solid.thickness=.005
  curve('Nervure principale',[(0,(k/n-.5)*.72,.08*math.sin(math.pi*k/n)+.003) for k in range(n+1)],.005,veinmat,obj)
  for v in range(1,7):
   t=v/8;w=math.sin(math.pi*t)*.19
   for sign in [-1,1]:curve('Nervure secondaire',[(0,(t-.5)*.72,.08*math.sin(math.pi*t)),(sign*w*.86,(t-.5)*.72+.055,.035*math.sin(math.pi*t))],.003,veinmat,obj)
  place(obj,(x+(j-.5)*.6,y+.08,.78),109+side*5+j*3,17,.3)

# Softbox illumination, fixed orthographic camera: consistent proportions per step.
bpy.ops.object.light_add(type='AREA',location=(-3,-4,7));bpy.context.object.data.energy=650;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=6
bpy.ops.object.light_add(type='AREA',location=(4,2,5));bpy.context.object.data.energy=230;bpy.context.object.data.size=5
bpy.ops.object.camera_add(location=(5,-7,7))
cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.5))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=8.2;cam.data.lens=50;scene.camera=cam
bpy.ops.wm.save_as_mainfile(filepath=str(out/'toast-pilot.blend'))
scene.frame_set(130);scene.render.filepath=str(out/'poster.png');bpy.ops.render.render(write_still=True)
if '--preview-only' not in sys.argv:
 scene.render.filepath=str(out/'frame_');bpy.ops.render.render(animation=True)
