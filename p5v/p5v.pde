import wblut.geom.*;
import wblut.hemesh.*;
import wblut.core.*;
import wblut.math.*;
import wblut.nurbs.*;
import wblut.*;
import wblut.processing.*;

import java.util.List;
import java.util.ArrayList;

List<WB_Point> points;
List<WB_VoronoiCell3D> voronoi;
List<Panel> panels = new ArrayList<Panel>();

WB_Render3D render;
WB_GeometryFactory gf=new WB_GeometryFactory();
WB_AABB box;
HE_Mesh mesh;
float diameter = 342;

HE_Mesh hull;
HE_Mesh dual;
WB_AABBTree tree;

HE_Mesh vMesh, v2Mesh;
WB_AABBTree vTree;

/*
look at the examples:
VoronoiOnSphere
SelectingVertices
Triangulation3D
*/

public class Panel{
  public Panel(WB_Point p){
    point = p;
    points = new ArrayList<WB_Point>();
    points.add(p);
    c = color(random(255), random(255), random(255));
  }
  
  public WB_Point point;
  public HE_Face face;
  public List<WB_Point> points;
  public HE_Selection selection;
  public color c;
}

WB_Point pointFromSpherical(float theta, float phi, float radius){
  return 
    new WB_Point(
      sin(phi)*cos(theta)*radius, 
      sin(phi)*sin(theta)*radius, 
      cos(phi)*radius);
}

WB_Point randomPointOnSphere(float radius){
  float u = random(1);
  float v = random(1);
  float theta = 2*PI*u;
  float phi = (float)Math.acos(2*v-1);
  return pointFromSpherical(theta, phi, radius);
}

void addPoint(
    List<WB_Point> points, float theta, float phi, float radius, boolean extras){
  points.add(pointFromSpherical(theta, phi, radius));
  if (extras){
    points.add(pointFromSpherical(theta, phi, radius - 8));
    points.add(pointFromSpherical(theta, phi, radius + 12));
  }
}

void setup(){
  size(800, 800, P3D);
  smooth(8);
  render= new WB_Render3D(this);
  
  HEC_Icosahedron creator=new HEC_Icosahedron();
  creator.setEdge(diameter);
  mesh=new HE_Mesh(creator);
  mesh.subdivide(new HES_CatmullClark(), 6);
  
  HEC_ConvexHull convexHull = new HEC_ConvexHull();
  List<WB_Point> hullPoints = new ArrayList<WB_Point>();
  
  points=new ArrayList<WB_Point>();
  
  for(float t : new int[]{0, 36, 72, 108, 144, 180, 216, 252, 288, 324}){
    for(float p : new int[]{52, 85, 95, 128}){
      float theta = (t + (p < 90 ? 2 : 0))*PI/180;
      float phi = p*PI/180;
      panels.add(new Panel(pointFromSpherical(theta, phi, diameter/2)));
      addPoint(points, theta, phi, diameter/2, true);
      addPoint(hullPoints, theta, phi, diameter/2, false);
    }
  }
  //panels.add(new Panel(pointFromSpherical(0, 0, diameter/2)));
  addPoint(points, 0, 0, diameter/2, true);
  addPoint(hullPoints, 0, 0, diameter/2, false);
  //panels.add(new Panel(pointFromSpherical(0, 0, -diameter/2)));
  addPoint(points, 0, 0, -diameter/2, true);
  addPoint(hullPoints, 0, 0, -diameter/2, false);
  
  convexHull.setPoints(hullPoints);
  hull = convexHull.createBase();
  hull.fuseCoplanarFaces(.0001);
  dual = new HEC_Dual(hull).createBase();
  dual.fuseCoplanarFaces(.0001);
  tree = new WB_AABBTree(dual, 1);
  
  /*
  float target = points.size() * 2;
  for(int i = 0; i < target; i++){
    points.add(randomPointOnSphere(diameter/2));
  }
  */
  
  box = new WB_AABB(-diameter, -diameter, -diameter, diameter, diameter, diameter);//mesh.getAABB();
  voronoi= WB_Voronoi.getVoronoi3D(points,box,0);
  vMesh = new HE_Mesh();
  
  //filter voronoi cells
  for(int i = voronoi.size()-1; i >= 0; i--){
    double[] p = voronoi.get(i).getGenerator().coords();
    if (round((float)(p[0] * p[0] + p[1] * p[1] + p[2] * p[2])) != round(pow(diameter/2, 2))){
      voronoi.remove(i);
    } else {
      HE_Mesh tempMesh = new HE_Mesh(voronoi.get(i).getMesh());
      tempMesh.fuseCoplanarFaces(.0001);
      vMesh.add(
        new WB_AABBTree(tempMesh, 1)
          .getClosestFace(voronoi.get(i).getGenerator().mul(1.1)));
    }
  }
  
  //vMesh.fuseCoplanarFaces(.0001);
  
  vTree = new WB_AABBTree(vMesh, 1);
  
  for(Panel p : panels){
    p.face = vTree.getClosestFace(p.point.mul(1.1));
  }
  
  for(int i = floor(panels.size()*1.5); i >= 0; i--){
    WB_Point point = randomPointOnSphere(diameter/2);
    HE_Face face = vTree.getClosestFace(point);
    for(Panel p : panels){
      if (face == p.face){
        p.points.add(point);
        break;
      }
    }
  }
  
  List<WB_Point> points2 = new ArrayList<WB_Point>();
  for(Panel p : panels){
    for(WB_Point pt : p.points){
      points2.add(pt.mul(1.1));
      points2.add(pt);
      points2.add(pt.mul(.95));
    }
  }
  addPoint(points2, 0, 0, diameter/2, true);
  addPoint(points2, 0, 0, -diameter/2, true);
  
  List<WB_VoronoiCell3D> voronoi2 = WB_Voronoi.getVoronoi3D(points2,box,0);
  v2Mesh = new HE_Mesh();
  
  for(WB_VoronoiCell3D v : voronoi2){
    for(Panel p : panels){
      if (p.points.contains(v.getGenerator())){
        HE_Mesh tempMesh = new HE_Mesh(v.getMesh());
        tempMesh.fuseCoplanarFaces(.0001);
        HE_Face face = 
          new WB_AABBTree(tempMesh, 1)
            .getClosestFace(v.getGenerator().mul(1.1));
        v2Mesh.add(face);
        if (p.selection == null){
          p.selection = v2Mesh.getNewSelection();
        }
        p.selection.add(face);
        break;
      }
    }
  }
      
  /*
  for(WB_VoronoiCell3D v : voronoi){
    WB_Plane plane = new WB_Plane(v.getGenerator(), v.getGenerator());
    WB_AABBTree tree = new WB_AABBTree(new HE_Mesh(v.getMesh()), 1);
    v.slice(plane);
    //List<WB_ExplicitSegment> intersection = HE_Intersection.getIntersection(tree, plane);
    //panels.add(new Panel(new HE_Mesh(v.getMesh()), v.getGenerator()));
  }*/
}
  
void draw() {
  background(55);
  //directionalLight(240, 240, 240, 1, 1, -1);
  directionalLight(127, 127, 127, 1, 1, -1);
  ambientLight(230, 230, 230);
  translate(width/2, height/2);
  fill(0);
  text("click",0,350);
  rotateY(mouseX*1.0f/width*TWO_PI);
  rotateX(mouseY*1.0f/height*TWO_PI);
  noFill();
  stroke(0);
  strokeWeight(2);
  render.drawPoint(points, 1); 
  strokeWeight(1);
  noFill();
  /*
  for(Panel p : panels){
    stroke(p.c);
    render.drawMesh(p.mesh);
  }*/
  for (WB_VoronoiCell3D vor : voronoi) {
    //render.drawMesh(vor.getMesh());
  }
  for (Panel p : panels){
    fill(p.c);
    noStroke();
    render.drawFaces(p.selection);
  }
  noFill();
  stroke(0);
  render.drawFaces(vMesh);
  stroke(255, 0, 0);
  //render.drawFaces(hull);
  stroke(0, 255, 0);
  //render.drawFaces(dual);
  fill(0, 0, 255);
  noStroke();
  //render.drawFace(tree.getClosestFace(points.get(0)));
}
