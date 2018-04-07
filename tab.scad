tabWidth = 7.05;
tabDepth = 1.95;
tabHeight = 10;
ridgeWidth = 1.1;
ridgeDepth = .5;
tolerance = .1;

module tab(center=true){
    x = (center ? ((tabWidth - ridgeWidth)/2) : (.85));
    translate([
        -(tabWidth+tolerance)/2,
        -(tabDepth+ridgeDepth+tolerance)/2,
        0])
    {
        cube([
            tabWidth + tolerance, 
            tabDepth + tolerance, 
            tabHeight + tolerance/2]);
        translate([x, 0, 0]){
            cube([
                ridgeWidth + tolerance, 
                ridgeDepth + tabDepth+tolerance, 
                tabHeight+tolerance/2]);
        }
    }
}

module tabHole(center=true, extended=0){
    translate([-5, -2.5, -11]){
        difference(){
            cube([10, 5, 11+extended]);
            union(){
                translate([5, 2.5, 0]){
                    tab(center);
                }
                translate([5-tabWidth/2+1, 0, 2]){
                    cube([tabWidth-2, 2.5, tabHeight-1-2]);
                }
            }
        }
    }
}