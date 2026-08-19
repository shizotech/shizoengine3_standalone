//@settings dtype=float32 format=rgba
//number of extra bows to add to the "n" shape, feel free to modify
#define ExtendNtoM floor((cos(iTime)*.5+.5) *8.)
//#define ExtendNtoM 8.

//above sets loop iterations, instead of using a "binary tree of mirrors".
//...that would likely outperform a loop with the same result.

/*
this is one tricky shape for my "bisymmetry optimization approach"
that I describe a lot here
https://www.shadertoy.com/view/4dSBWV

its main issue is that the upper bow of the "n,m,h" shape is defined by abs(length())
and you can not pull the length() out of the abs() wrapper too efficiently.
while you usually can do that for many other shapes.

converting abs() into its branch, into its branchless sign() binomial ...
...is unlikely worth anything here.

A private (simpler) parent of this shader is 
https://www.shadertoy.com/view/Xs2BWV
*/

#define frame(u) (u-.5*iResolution.xy)*17./iResolution.y


float maxv(vec2 a){return max(a.x,a.y);}
float maxv(vec3 a){return max(maxv(a.xy),a.z);}
#define minv(a) -maxv(-a)

//#define stretch(c,m) v=mix(v-m,mix(0.,v,step(v,0.)),step(v,m));
//stretch      ; centric, most commonly used, therefore atomic
#define mStretch(u,m) .5*(sign(u)*m-u)*((sign(abs(u)-m))+1.)
//stretch nimus; positive values do not change
#define mStretchM(u,m) mStretch((u*2.+m),m)*.5
//vec2  mStretchM(vec2  u,vec2  m){m*=.5;u= u+m;return  mStretch(u,m);}
//stretch plus ; negative values do not change
#define mStretchP(u,m) mStretch((u*2.-m),m)*.5
//based on #define analstretching(u,m) mix(u-m,mix(vec2(0.),u,step(u,vec2(0.))),step(u,m))
//above is special case that can include the sat() generalization below +u.x;
//a generalization of clamp(a,0.,1.); for m=vec2(1)
float sat(float a,vec2 m){    
 a=.5*(sign(a)+m.x)*a+m.y;
 a=(sign(2.-a)+1.)*(a-2.)+2.; 
 return a*.5;}
float sat(float a){return sat(a,vec2(1));}//return clamp(a,0.,1.); 

/*
//explicit atan2(y,x), hopefully slightly more worksave?
float ata(float x,float y){
 //return atan(x/y);//not quite as work save as below? or rautological either way?
 float a=.5*(1.-sign(x));//pi and -pi are equally valid. doesnt matter which way you rotate?
 float b=atan(x/y);//division by 0 is poblematic, unless multiplied by 0.
 float s=step(y,0.)+step(0.,y)-1.;
 //why do i end u in this tautology?
 //my solution is that equality is an ideal fiction.
 //while the reality is heuristic gradients.
 //the ideal is tautological, art, with null utility.
 return mix(b,a,s);}
*/

/*
float cane1(vec2 u,vec4 m){
 if(u.y>0.)return abs(length(u)-1.);
  u.x-=1.;
 if(u.y>m.y)return abs(u.x);return length(u-vec2(0,m.y));
}*/


/*
float halfWorm11(vec2 u){
 float a=length(sign(u.y)*vec2(.5,0)+vec2(abs(u.x)-.5,u.y));
 return abs(a-.5*(1.+sign(u.y)));}
*/


/*
vec2 left(vec2 u,vec4 m){
 u.y=(mStretchM((u.y-m.x),(m.x+m.y)));
 vec2 e=vec2(u.x+2., u.y );return e;}
vec2 right(vec2 u,float m){u.y=mStretchM(u.y,m);return u;}
*/

/*
//incomplete cane, extension to make m and n...
//so far this special case has proven obsolete, inferior. therefore i am nt even developing it.
float cane3(vec2 u,vec4 m){
 m=abs(m);
 if(u.y>0.)return abs(length(u)-1.);//the abs outside the length is the main issue here.
 u.x-=1.;   
 return sqrt(abs(dd(vec2(u.x,mStretchM(u.y,m.y)))));
 return abs(length(vec2(u.x,mStretchM(u.y,m.y))));
}*/

/*
vec2 halfWorm1h(vec2 u){
 //if(0.>u.y)return inf;
 u.x=abs(u.x)-1.;
    return u;
 //float c=(u)-1.;
 //return abs(c);
}*/



//the above "cane" shapes are only needed for "j" and "2", maybe "3,6,9,G,R,S" ?
//but the "m,n" is less efficient when using "cane", better use overlapping "u"

#define dd(a) dot(a,a)


//upside down u-shape
float shapeU(vec2 u,vec4 m){
 m=abs(m);
 if(u.y>0.)return abs(length(u)-1.);//the abs outside the length is the main issue here.
 return sqrt(abs(dd(vec2(abs(u.x)-1.,mStretchM(u.y,m.y)))));}//here the sqrt can be outside.

//mm2() sure simplifies things
//the dull "mm2" shape, suffers from cane3() containing abs(length())
float mm2(vec2 u,vec4 m){m=abs(m);vec2 r;
 r.y=length(vec2(u.x+1.        ,mStretchP(u.y,m.x)   ));   
 r.x=shapeU(vec2(abs(u.x-1.)-1.,u.y),m);                   
 return minv(r.xy);}

//cane2() splits the abs(length) case from the non abs(length) case.

//only the vertical lines of an "m" shape! this has some "fun" bisymmetry
vec2 mlines(vec2 u,vec4 m){m=abs(m);
 float o=(ExtendNtoM)*2.;
 if(ExtendNtoM<1.)o=2.;                        
 vec2 e=vec2(u.x+o, (mStretchM((u.y-m.x),(m.x+m.y))) );//left bar(s) 
 //(m.x+m.y) can be reduced, depending on ratio
 for(float a=0.;a<ExtendNtoM;a++){u.x=abs(u.x-1.)-1.;} //multiple right bars
 u.y=mStretchM(u.y,m.y);         //right bars
 //by changing the bisymmetry below, you can get multiple "left bars"
 //but not in its binomial form as it is below, you need to muultiply that one out...
 float t=sign(dd(u)-dd(e))+1.;//bisymmetry sign
 vec2 l=u+.5*(e-u)*t;         //bisymmetry binomial
 return l;}
//"smart n-m shapes, utilizing mlines()
//the above liikely nicely merges into the below?
float cane2(vec2 u,vec4 m){
 float l=length(mlines(u,m));
 if(u.y<0.)return l;//lower half of fragments skips the calculation of the arc!
 for(float a=0.;a<ExtendNtoM;a++){u.x=abs(u.x)-2.;}//multiple right arcs
 float w=length(vec2(u.x+1.,u.y));//halfWorm1h(u);
 float r=min(w,l+1.);
     //r=sqrt(dd(w));r=sqrt(dd(l))+1.;
   //  r=sqrt(min((dd(w))+1.,(dd(l)))); //getting the sqrt() out, seems to not be worth it.
 return abs(r-1.);
}

void mainImage(out vec4 O,in vec2 U){
 vec2 u=frame(U);
 vec4 m=vec4(frame(iMouse.xy),frame(iMouse.zw));

 vec3 c=vec3(0);
 u.x+=1.;
 //c.r=cane1(u,m)-.2;
 c.b=shapeU(u,m)-.3;//a base shape for mm2(), "u" shape easily defeats "r"shape"
 c.g=mm2(u,m)-.3;   //a straightforward solution, using shapeU()
 u.x-=1.;
 c.r=cane2(u,m)-.3;//me trying to imptove the unimprovable, by not using shapeU()
 //cane2() splits one problem of mm2() into 2 smaller problems.
 //one of these 2 seems unsolvable, the other one is just too hard for me to boher.
    
 c=abs(c-.4)-.2;//turn into outline of self
    
 //c.b=smoothstep(.1,-.1,c.b);
 #if 1
 float fuzz=9./min(iResolution.x,iResolution.y);
 c=smoothstep(fuzz,-fuzz,c);
 #else
 c=fract(c*2.);
 #endif
 O= vec4(c,1);
}
