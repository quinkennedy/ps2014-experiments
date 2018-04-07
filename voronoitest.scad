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

spherical = [
  for(t = [0 : 36 : 359], z = [0, 52, 85, 95, 128, 180]) 
    [diameter/2, z > 90 ? t + 2 : t, z]
];

points3d = [ for(p = spherical) spher_rect(p[0], p[1], p[2]) ];

//midpoints = [ for(f = points3d)

hull = hull(points3d);

function cat(L1, L2) = [for (i=[0:len(L1)+len(L2)-1]) 
                        i < len(L1)? L1[i] : L2[i-len(L1)]] ;

module drawAround(i){
  p1Faces = [
    for(f = hull)
      if (len([
        for(p = f) 
          if (p == i) true
      ]) > 0) f];
  //echo(p1Faces);
  p1Neighbors = [
    for(f = p1Faces)
      f[0] == i ? f[2] : f[1] == i ? f[0] : f[1]
  ];
  p1CloseNeighbors = [
    for(n = p1Neighbors)
      if (abs(n - i) < 7) n
  ];
  //echo(p1CloseNeighbors);
  p1MidPoints = [
    for(n=p1Neighbors)
      (points3d[n] + points3d[i])/2
  ];
  points = cat(p1MidPoints, [points3d[i]]);
  p1MidExt = [
    for(p = points)
      let(s=rect_spher(p))
        spher_rect(diameter/2+2, s[1], s[0])
  ];
  pointsFar = [
    for(p=points)
      let(s=rect_spher(p))
        spher_rect(diameter, s[1],s[0])
  ];
  p1MidSurface = [
    for(p = points)
      let(s=rect_spher(p))
        spher_rect(diameter/2, s[1], s[0])
  ];
  //pSurf = cat(p1MidSurface, [points3d[i]]);
  pSurf = cat(p1MidExt, p1MidSurface);
  pointAroundHull = hull(pSurf);
  pSubSurf = cat(p1MidSurface, p1MidPoints);
  subPoints = hull(pSubSurf);
  
  faceted=false;
  
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
          sphere(d=diameter+2, $fn=13);
          sphere(d=diameter, $fn=13);
        }
        polyhedron(points=pointsFarCenter, faces=hullFarCenter);
      }
    } else {
      
      // flattened to tangential plane
      intersection(){
        placePlane(i);
        polyhedron(points=pointsFarCenter, faces=hullFarCenter);
      }
    }
  }
  //visualize_hull(p1midPoints);
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

module placeTabHole(i){
    rotate([spherical[i][2], 0, spherical[i][1] + 90]){
        translate([0, 0, getTabDist(spherical[i][2])/*spherical[i][0]*/]){
            rotate([0, 0, getTabRot(spherical[i][2])]){
                tabHole(center=isTabCenter(spherical[i][2]), extended=.5);
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

drawAll = false;

if (drawAll){
  for(i=[1:8]){
    drawAround(i*6+1);
    drawAround(i*6+2);
    drawAround(i*6+3);
    drawAround(i*6+4);
  }
} else {
  //translate([0, 0, -diameter/2]){
    //rotate([180-spherical[13][2], 0, 0]){
  rotate([0, 180-spherical[13][2], 0]){
      rotate([0, 0, -spherical[13][1]]){
        union(){
          drawAround(13);
          //placeTabHole(13);
        }
      }
    }
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