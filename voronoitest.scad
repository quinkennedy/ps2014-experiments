include <tab.scad>
diameter = 342;

function spher_rect(r,theta,zenit) = 
[ r*(sin(zenit)*cos(theta)) , r*(sin(zenit)*sin(theta)), r*cos(zenit) ];

function rect_spher(p) =
[ acos(p[2]/sqrt(p[0]*p[0]+p[1]*p[1]+p[2]*p[2])), atan2(p[1], p[0])];

/**
 * 3d voronoi
 */
include <scad-utils/hull.scad>

both = true;
inv = true;
zs = [10, 52, 85, 95, 128, 170];
zsi = [170, 128, 95, 85, 52, 10];
ts = [-36, 0, 36];
tsi = [36, 0, -36];

spherical = [
  for(t = ts, z = zs) 
    [
      diameter/2, 
      (z > 90 ? t + 2 : t) + (z == zs[0] || z == zsi[0] ? 18 : 0), 
      z]
];
sphericali = [ 
  for(t = ts, z = zsi) 
    [
      diameter/2, 
      (z > 90 ? t + 2 : t) + (z == zs[0] || z == zsi[0] ? 18 : 0), 
      z]
];

points3d = [ for(p = spherical) spher_rect(p[0], p[1], p[2]) ];
points3di = [ for(p = sphericali) spher_rect(p[0], p[1], p[2]) ];

//midpoints = [ for(f = points3d)

hull = hull(points3d);
hulli = hull(points3di);

offsets = rands(.5, .5, len(points3d) * 10, 310);
retractAmt = 10;
crustThickness = 2;

function cat(L1, L2) = [for (i=[0:len(L1)+len(L2)-1]) 
                        i < len(L1)? L1[i] : L2[i-len(L1)]];

function contains(L1, e) = 
  len(
    [ for(p=L1) 
      if (p == e) 
        true
    ]
  ) > 0;

function contains3d(L1, e) = 
  len(
    [ for(p=L1) 
      if (p[0] == e[0] && p[1] == e[1] && p[2] == e[2]) 
        true
    ]
  ) > 0;

function join(L1, L2) = 
  cat(
    [for(p=L1) if (contains(L2, p) == false) p],
    L2);

//get all faces which include the specified vertex.
function facesIncluding(faces, targetIndex) = [
  //for each face in the hull.
  for(face = faces)
    //if one of the vertices is the target point.
    if(
      len([
        for(vertexIndex = face)
          if (vertexIndex == targetIndex) true
      ]) > 0) face
];

//Get all points directly connected to the target point.
//This assumes that the target point is
// completely surrounded (no gaps in geometry)
function getNeighborPoints(faces, targetIndex) = [
  let (neighborFaces = facesIncluding(faces, targetIndex))
    for(face = neighborFaces)
      face[0] == targetIndex 
        ? face[2] 
        : face[1] == targetIndex 
          ? face[0] 
          : face[1]
];

//move the provided point toward or away from 0,0,0
// to match the given radius
function putOnSphere(radius, point) =
  let(s=rect_spher(point))
    spher_rect(radius, s[1], s[0]);

function uninverse(L) =
    [for(i = L) 
      i <= 5 
        ? 5 - i 
        : i <= 11 
          ? 11 - (i - 6) 
          : 17 - (i - 12)];//len(points3d)-1 - i];

module drawAround(column, row){
  targetPoint = 7 + row;
  targetPointi = 10 - row;
  //get all points that share an edge with this point
  neighbors = getNeighborPoints(hull, targetPoint);
  neighborsi = uninverse(getNeighborPoints(hulli, targetPointi));
  p1Neighbors = 
    both 
      ? join(neighbors, neighborsi)
      : inv
        ? neighborsi
        : neighbors;
      
  //echo(p1Neighbors);
  //get the points midway between
  // the target point and each neighbor
  p1MidPoints = [
    for(n=p1Neighbors)
      let(
        offin = (column == 9 && n >= targetPoint + 5)
          ? targetPoint - 6
          : min(n, targetPoint) + 6*column,
        dist = magnitude(points3d[n] - points3d[targetPoint]),
        retractPct = retractAmt/dist,
        offset = 
          n==0 || n == 6 || n == 5
            ? 1 
            : n == 11 
              ? 0
              : offsets[offin],
        alpha = (n < targetPoint ? offset : 1-offset) - retractPct
      )
        (points3d[n] * alpha + 
          points3d[targetPoint] * (1.0-alpha))
  ];
  //include the target point in the set for hull creation
  points = cat(p1MidPoints, [points3d[targetPoint]]);
  //extend all midpoints slightly beyond 
  // the surface of the sphere
  p1MidExt = [ for(p = points) putOnSphere(diameter/2+crustThickness, p) ];
  //project all points out to a very large sphere
  pointsFar = [
    for(p=points)
      putOnSphere(diameter, p)
  ];
  //project all points exactly onto the sphere
  p1MidSurface = [
    for(p = points)
      putOnSphere(diameter/2, p)
  ];
  p1MidOnlySurface = [
    for(p=p1MidPoints)
      putOnSphere(diameter/2, p)
  ];
  //create a thin shell starting at the surface
  // defined by the raw midpoint geometry
  pSurf = cat(p1MidExt, p1MidSurface);
  pointAroundHull = hull(pSurf);
  //create a geometry with its outside
  // on the surface of the sphere
  pSubSurf = cat(p1MidSurface, p1MidPoints);
  subPoints = hull(pSubSurf);
  
  faceted=true;
  
  rotate([0, 0, 36*column]){
  
    if (faceted){
      // faceted along sphere surface
      difference(){
        polyhedron(points=pSurf, faces = pointAroundHull);
        polyhedron(points=pSubSurf, faces=subPoints);
      }
    } else {
      sphered = false;
      pointsFarCenter = cat(pointsFar, [[0,0,0]]);
      hullFarCenter = hull(pointsFarCenter);
      if (sphered){
        intersection(){
          difference(){
            sphere(d=diameter+crustThickness, $fn=100);
            sphere(d=diameter, $fn=100);
          }
          polyhedron(points=pointsFarCenter, faces=hullFarCenter);
        }
      } else {
        voronoi = false;
        if (voronoi){
          union(){
            for(p=p1MidOnlySurface){
              placeAtTarget(targetPoint){
                cube(
                  magnitude(p - points3d[targetPoint]),
                  true);
              }
            }
          }
        } else {
          // flattened to tangential plane
          intersection(){
            placePlane(targetPoint);
            polyhedron(
              points=pointsFarCenter, 
              faces=hullFarCenter);
          }
        }
      }
    }
  }
  //visualize_hull(p1midPoints);
}

function magnitude(v) =
  sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2]);

module placeAtTarget(i){
  rotate([spherical[i][2], 0, spherical[i][1] + 90]){
    translate([0, 0, diameter/2]){
      children();
    }
  }
}

module placePlane(i){
    rotate([spherical[i][2], 0, spherical[i][1] + 90]){
        translate([-100, -100, diameter/2]){
            cube([200, 200, 1]);
        }
    }
}

function getTabDist(z) =
    z == 52 || z == 128 ? diameter/2/*150*/ : diameter/2/*153.5*/;

function getTabRot(z) = 
    z > 90 ? -90 : 90;

function isTabCenter(z) =
    z == 85 || z == 95;

module placeTabHole(column, row){
  index = 7 + row;
  rotate([
    spherical[index][2], 
    0, 
    36*column + 90
    /*spherical[index][1] + 90*/])
  {
    translate([0, 0, getTabDist(spherical[index][2])/*spherical[index][0]*/]){
      rotate([0, 0, getTabRot(spherical[index][2])]){
        tabHole(
          center=isTabCenter(spherical[index][2]), 
          extended=.5);
      }
    }
  }
}

module placeTab(i){
    rotate([spherical[i][2], 0, spherical[i][1] + 90]){
        translate([0, 0, getTabDist(spherical[i][2])/*spherical[i][0]*/]){
            rotate([0, 0, getTabRot(spherical[i][2])]){
                tabHole();
            }
        }
    }
}

drawAll = true;

if (drawAll){
  onlytwo=false;
  cSet = (onlytwo ? [0] : [for(c =[0:9]) c]);
  for(r=[0:3], c=cSet){
    drawAround(c,r);
  }
} else {
  twoD = false;
  if (twoD){
    projection(){
      rotate([0, 180-spherical[13][2], 0]){
        rotate([0, 0, -spherical[13][1]]){
          union(){
            drawAround(13);
            placeTabHole(13);
          }
        }
      }
    }
  } else {
    c = 9;
    r = 1;
    union(){
      drawAround(c,r);
      placeTabHole(c,r);
    }
  }
  //translate([0, 0, -diameter/2]){
    //rotate([180-spherical[13][2], 0, 0]){
}

/*for(i=[12:17]){
    union(){
        placeTab(i);
        drawAround(i);
    }
}*/    

//polyhedron(points = points3d, faces = p1Faces);

//visualize_hull(points3d);

/**
 * 2d voronoi
 *//*
include <openscad_voronoi_generator/voronoi.scad>

points2d = [for (t=[0 : 36 : 359], z = [52, 85, 95, 128]) [z > 90 ? t + 2 : t, z] ];

voronoi(points2d);
*/
/*phi = 1.618033988749895;

testpoints_on_sphere = [ for(p = 
	[
        sphere_rect(diameter/2, 0, 85),
		[1,phi,0], [-1,phi,0], [1,-phi,0], [-1,-phi,0],
		[0,1,phi], [0,-1,phi], [0,1,-phi], [0,-1,-phi],
		[phi,0,1], [-phi,0,1], [phi,0,-1], [-phi,0,-1]
	])
	unit(p)
];
visualize_hull(20*testpoints_on_sphere);
*/