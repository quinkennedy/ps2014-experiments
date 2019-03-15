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
float diameter = 342;

HE_Mesh vMesh, v2Mesh;
WB_AABBTree vTree;

/*
look at the examples:
VoronoiOnSphere
SelectingVertices
Triangulation3D
*/

public class Spherical{
  public Spherical(float t, float p, float r){
    theta = t;
    phi = p;
    radius = r;
  }
  
  public Spherical(WB_Point p){
    double[] coords = p.coords();
    radius = sqrt((float)(coords[0] * coords[0] + coords[1] * coords[1] + coords[2] * coords[2]));
    phi = acos((float)(coords[2] / radius));
    theta = acos((float)(coords[0]/(radius * sin(phi))));
  }
  
  public WB_Point getPoint(){
    return pointFromSpherical(theta, phi, radius);
  }
  
  public float theta;
  public float phi;
  public float radius;
}

public class Panel{
  public Panel(Spherical p){
    spherical = p;
    point = p.getPoint();
    points = new ArrayList<WB_Point>();
    points.add(point);
    c = color(random(255), random(255), random(255));
  }
  
  public Spherical spherical;
  public WB_Point point;
  public HE_Face face;
  public List<WB_Point> points;
  public HE_Selection selection;
  public color c;
  public HE_Mesh mesh;
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
  
  //A points array containing all the voronoi cell centers
  points=new ArrayList<WB_Point>();
  
  //fill the points array with all the attachment points
  for(float t : new int[]{0, 36, 72, 108, 144, 180, 216, 252, 288, 324}){
    for(float p : new int[]{52, 85, 95, 128}){
      float theta = (t + (p < 90 ? 2 : 0))*PI/180;
      float phi = p*PI/180;
      panels.add(new Panel(new Spherical(theta, phi, diameter/2)));
      addPoint(points, theta, phi, diameter/2, true);
    }
  }
  
  //also add points to generate "keep out" areas at the poles
  //panels.add(new Panel(pointFromSpherical(0, 0, diameter/2)));
  addPoint(points, 0, 0, diameter/2, true);
  //panels.add(new Panel(pointFromSpherical(0, 0, -diameter/2)));
  addPoint(points, 0, 0, -diameter/2, true);
  
  /*
  float target = points.size() * 2;
  for(int i = 0; i < target; i++){
    points.add(randomPointOnSphere(diameter/2));
  }
  */
  
  //generate the simple voronoi sphere
  box = new WB_AABB(-diameter, -diameter, -diameter, diameter, diameter, diameter);//mesh.getAABB();
  voronoi= WB_Voronoi.getVoronoi3D(points,box,0);
  
  //migrate desired voronoi faces to a reference mesh
  vMesh = new HE_Mesh();
  //filter voronoi cells
  for(int i = voronoi.size()-1; i >= 0; i--){
    double[] p = voronoi.get(i).getGenerator().coords();
    if (
        round(
          (float)(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]) - 
          pow(diameter/2, 2)) != 
        0){
      //remove the voronoi cells that are used for enforcing the voronoi "shell"
      // i.e. generators that are not on the sphere surface
      voronoi.remove(i);
    } else {
      //otherwise, add the external face of the voronoi cell to our reference mesh
      HE_Mesh tempMesh = new HE_Mesh(voronoi.get(i).getMesh());
      tempMesh.fuseCoplanarFaces(.0001);
      vMesh.add(
        new WB_AABBTree(tempMesh, 1)
          .getClosestFace(voronoi.get(i).getGenerator().mul(1.1)));
    }
  }
  
  //set up search tree for finding closest planes in reference mesh
  vTree = new WB_AABBTree(vMesh, 1);
  
  //associate each face with it's source point
  for(Panel p : panels){
    p.face = vTree.getClosestFace(p.point.mul(1.1));
  }
  
  //create random points on the sphere,
  // if they are in the space "owned" by one of the attachment points
  // add it to that panel's set of points
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
  
  //add all the points for voronoi shell generation
  List<WB_Point> points2 = new ArrayList<WB_Point>();
  for(Panel p : panels){
    for(WB_Point pt : p.points){
      points2.add(pt.mul(1.05));
      points2.add(pt);
      points2.add(pt.mul(.95));
    }
  }
  //don't forget the "keep out" area for the poles
  addPoint(points2, 0, 0, diameter/2, true);
  addPoint(points2, 0, 0, -diameter/2, true);
  
  //generate the new voronoi set
  List<WB_VoronoiCell3D> voronoi2 = WB_Voronoi.getVoronoi3D(points2,box,0);
  
  //move outer faces to a new mesh
  // and group them into selections
  // based on their "parent" panel/attachment point
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
          p.mesh = new HE_Mesh(v.getMesh());
        } else {
          p.mesh.fuse(new HE_Mesh(v.getMesh()));
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
  //clear screen
  background(55);
  
  //set up lighting
  //directionalLight(240, 240, 240, 1, 1, -1);
  directionalLight(127, 127, 127, 1, 1, -1);
  ambientLight(230, 230, 230);
  
  translate(width/2, height/2);
  fill(0);
  //rotate based on mouse position
  rotateY(mouseX*1.0f/width*TWO_PI);
  rotateX(mouseY*1.0f/height*TWO_PI);
  
  //draw the attachment points
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
  //draw each panel's faces in its color
  for (Panel p : panels){
    noFill();//fill(p.c);
    stroke(p.c);//noStroke();
    render.drawFaces(p.mesh);//p.selection);
  }
  
  //draw the mesh of the "raw" panels
  noFill();
  stroke(0);
  //render.drawFaces(vMesh);
  
  stroke(255, 0, 0);
  //render.drawFaces(hull);
  stroke(0, 255, 0);
  //render.drawFaces(dual);
  fill(0, 0, 255);
  noStroke();
  //render.drawFace(tree.getClosestFace(points.get(0)));
}

void keyPressed(){
  if (key == 's'){
    int i = 0;
    for (Panel p : panels){
      if (p.mesh != null){
      p.mesh.triangulate();
      Spherical s = p.spherical;
      p.mesh.rotateAboutOriginSelf(-s.theta, 0, 0, 1);
      p.mesh.rotateAboutOriginSelf(-s.phi, 0, 1, 0);
      //if (s.phi < PI/3 && s.theta < PI/4){
      //  p.mesh.rotateAboutOriginSelf(-s.phi, pointFromSpherical(s.theta + PI/2, PI/2, 1));
      //} else {
      //  p.mesh = null;
      //}
      String name = round(s.theta * 180/PI) + "_" + round(s.phi * 180/PI);
      HET_Export.saveToSTL(p.mesh, sketchPath("exports"), name);
      i++;
      }
    }
  }
}
