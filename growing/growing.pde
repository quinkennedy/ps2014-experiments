import wblut.geom.*;
import wblut.hemesh.*;
import wblut.core.*;
import wblut.math.*;
import wblut.nurbs.*;
import wblut.*;
import wblut.processing.*;
import java.util.ArrayList;

HE_Mesh mesh;
WB_Render render;
WB_AABBTree tree;
ArrayList<Panel> panels = new ArrayList<Panel>();

public class Panel{
  public Panel(float theta, float phi, HE_Mesh mesh, WB_AABBTree tree){
    this.selection = mesh.getNewSelection();
    theta = theta*PI/180;
    phi = phi*PI/180;
    coord = new WB_Coordinate(
      sin(phi)*cos(theta)*400, 
      sin(phi)*sin(theta)*400, 
      cos(phi)*400);
    this.selection.add(tree.getClosestFace(coord));
    c = color(random(255), random(255), random(255));
  }
  
  public float theta;
  public float phi;
  public WB_Coordinate coord;
  public HE_Selection selection;
  public color c;
}

void setup() {
  size(800,800,P3D);
  smooth(8);
  HEC_Icosahedron creator=new HEC_Icosahedron();
  creator.setEdge(400); 
  //alternatively 
  //creator.setRadius(200);
  //creator.setInnerRadius(200);// radius of sphere inscribed in cube
  //creator.setOuterRadius(200);// radius of sphere circumscribing cube
  //creator.setMidRadius(200);// radius of sphere tangential to edges
  mesh=new HE_Mesh(creator);
  mesh.subdivide(new HES_CatmullClark(), 5);

  render=new WB_Render(this);
  tree = new WB_AABBTree(mesh, 4);
  
  for(float t : new int[]{0, 36, 72, 108, 144, 180, 216, 252, 288, 324}){
    for(float p : new int[]{52, 85, 95, 128}){
      panels.add(new Panel(t + (p > 90 ? 2 : 0), p, mesh, tree));
    }
  }
  //panels.add(new Panel(0, 0, mesh, tree));
  //panels.add(new Panel(0, 180, mesh, tree));
}



void draw() {
  background(55);
  directionalLight(255, 255, 255, 1, 1, -1);
  directionalLight(127, 127, 127, -1, -1, 1);
  translate(width/2,height/2);
  rotateY(frameCount*0.005);
  //rotateY(mouseX*1.0f/width*TWO_PI);
  rotateX(PI/2);
  //rotateX(mouseY*1.0f/height*TWO_PI);
  stroke(0);
  //render.drawEdges(mesh);
  noStroke();
  fill(255);
  //render.drawFaces(mesh);
  for(Panel p : panels){
    fill(p.c);
    render.drawFaces(p.selection);
  }
  if (frameCount%10==0){
    mousePressed();
  }
}

void mousePressed(){
  for(Panel p : panels){
    p.selection.surround();
  }
}
