"""Shared modeling and clamped keyframes, matching the existing plating pilot."""
import bpy, math, random
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
