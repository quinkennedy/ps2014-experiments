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

public class Panel{
  public Panel(HE_Mesh m, WB_Point p){
    mesh = m;
    point = p;
    c = color(random(255), random(255), random(255));
  }
  
  public HE_Mesh mesh;
  public WB_Point point;
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

void addPoint(List<WB_Point> points, float theta, float phi, float radius){
  points.add(pointFromSpherical(theta, phi, radius));
  points.add(pointFromSpherical(theta, phi, radius - 8));
  points.add(pointFromSpherical(theta, phi, radius + 12));
}

void setup(){
  size(800, 800, P3D);
  smooth(8);
  render= new WB_Render3D(this);
  
  HEC_Icosahedron creator=new HEC_Icosahedron();
  creator.setEdge(diameter);
  mesh=new HE_Mesh(creator);
  mesh.subdivide(new HES_CatmullClark(), 6);
  
  points=new ArrayList<WB_Point>();
  
  for(float t : new int[]{0, 36, 72, 108, 144, 180, 216, 252, 288, 324}){
    for(float p : new int[]{52, 85, 95, 128}){
      float theta = t*PI/180;
      float phi = p*PI/180;
      addPoint(points, theta, phi, diameter/2);
    }
  }
  addPoint(points, 0, 0, diameter/2);
  addPoint(points, 0, 0, -diameter/2);
  /*
  float target = points.size() * 2;
  for(int i = 0; i < target; i++){
    points.add(randomPointOnSphere(diameter/2));
  }
  */
  
  box = new WB_AABB(-diameter, -diameter, -diameter, diameter, diameter, diameter);//mesh.getAABB();
  voronoi= WB_Voronoi.getVoronoi3D(points,box,4);
  
  //filter voronoi cells
  for(int i = voronoi.size()-1; i >= 0; i--){
    double[] p = voronoi.get(i).getGenerator().coords();
    if (round((float)(p[0] * p[0] + p[1] * p[1] + p[2] * p[2])) != round(pow(diameter/2, 2))){
      voronoi.remove(i);
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
  directionalLight(255, 255, 255, 1, 1, -1);
  directionalLight(127, 127, 127, -1, -1, 1);
  translate(width/2, height/2);
  fill(0);
  text("click",0,350);
  rotateY(mouseX*1.0f/width*TWO_PI);
  rotateX(mouseY*1.0f/height*TWO_PI);
  noFill();
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
    render.drawMesh(vor.getMesh());
  }
}
