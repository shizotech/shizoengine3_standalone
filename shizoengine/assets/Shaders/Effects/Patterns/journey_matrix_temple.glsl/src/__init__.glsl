

//@settings dtype=float32 format=rgba

#define pi acos(-1.)

const int Iterations=13;
const float detail=.00009;
const float Scale=1.9999;
vec3 lightdir=normalize(vec3(0.,-1,-1.));

  float eyes3;

float ot=0.;
float det=0.;

float hitfloor;
float hitrock;

float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}
mat3 rotate( in vec3 v, in float angle)
{
 float c = cos(radians(angle));
 float s = sin(radians(angle));	
 return mat3(c + (1.0 - c) * v.x * v.x, (1.0 - c) * v.x * v.y - s * v.z, (1.0 - c) * v.x * v.z + s * v.y,
 (1.0 - c) * v.x * v.y + s * v.z, c + (1.0 - c) * v.y * v.y, (1.0 - c) * v.y * v.z - s * v.x,
 (1.0 - c) * v.x * v.z - s * v.y, (1.0 - c) * v.y * v.z + s * v.x, c + (1.0 - c) * v.z * v.z
 );
}
float tt;

float dBox(vec3 p, vec3 s)
{
 return length (max (abs(p)-s,0.));   
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float sdEllipsoid( vec3 p, vec3 r )
{
  float k0 = length(p/r);
  float k1 = length(p/(r*r));
  return k0*(k0-1.0)/k1;
}


float sdRoundBox( vec3 p, vec3 b, float r )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}



float g1;
float g2;
float g3;
float g4;
float g5;

float de(vec3 pos) {
 vec3 o5 = pos;
 hitfloor=0.;
 hitrock=0.;
 vec3 p10; 
 vec3 p2 = pos;
 vec3 p=pos;
 p.z=abs(0.5-mod(pos.z,1.));
 float DEfactor=1.;
 for (int i=0; i<Iterations; i++) {
  p = abs(p)-vec3(.452,2.,0.);  
  float r2 = dot(p*vec3(0.,10.,1.), p)*.2;
  float sc=Scale/clamp(r2,sin(abs(p.y-0.0)*.0)*.00,1.);
  p*=sc; 
  DEfactor*=sc;
  p = p - vec3(0.1,13.,0.5);
 }
 //definition
 float d=length(p)/DEfactor-.0003;
 vec3 from=vec3(-0.049,3.059,-iTime*-0.002+0.025);
 float sep = 0.0;  
 p2.x = abs(p2.x-sep);
 from.x = abs(from.x-sep); 
 p2 -= vec3(-0.32,0,.0);
 vec3 p3 =  p2;
 p2 -=from;
 float gap = .03; 
 from.z = mod(from.z + gap,2. * gap) - gap;
 p2.z = mod(p2.z + gap,2. * gap) - gap;
 gap = .03;   
 from.x = mod(from.x + gap,2. * gap) - gap;
 p2.x = mod(p2.x + gap,2. * gap) - gap;
 float e;
 float   the = sin(pos.z*30.+iTime)*0.1;
 //p2.xy *= mat2(cos(the), -sin(the), sin(the), cos(the));
 the = sin(pos.z*20.+iTime)*.1;
// p2.xz *= mat2(cos(the), -sin(the), sin(the), cos(the));
 the = (0.2)*1.;
 //p2.xz *= mat2(cos(the), -sin(the), sin(the), cos(the));
 from.xz *= -mat2(cos(the), -sin(the), sin(the), cos(the));  
 p2.x=(p2.x)-0.003;
 float eyes2;
 float y2;
 float eyes6;
 for(float i=0.; i<4.; i++)    
 {
 p2 = rotate( ( vec3(0.,1., 0. )),90.)*p2;
 p2.xz += 1.*0.006;
 float e = dBox(p2,vec3(0.006,.03,.000));
 float nose = dBox(p2,vec3(abs(sin(p2.y*100.+2.2)*2.)*0.001,(sin(p2.x*10.+2.2)*2.)*.002,abs(sin(p2.y*100.+2.2))*.003));    
 vec3 p3 =  p2;
 p3 -= vec3(-0.000,0.002,0.0001);
 p3.xz = abs(p3.xz)-.003;
 float eyes = sdRoundBox(p3,vec3(0.0019,.0013,.02),0.0001);  
 p3 -= vec3(-0.002,0.007,-0.002);
 eyes2 = dBox(p3,vec3(0.0004,.002,.0002));  
 p3 -= vec3(-0.0002,-0.045,0.01);

 float eyes5 = dBox(p3,vec3(0.04,.0003,.002));  

 vec3 p4 =  p2;
 p4.xz = abs(p4.xz)-0.001;
 p4 -= vec3(0.000,-0.006,0.001);
 p4.y = abs(p4.y)-0.0005;
 float mond = dBox(p4,vec3(0.002,(sin(p4.x*-200.+0.4)*4.)*.0002,.0001)); 
 vec3 p5 =  p2;
 e =smin(e,mond,0.002);
 e = min(e,nose);
 float y =min(eyes2, max(e,-eyes));
      y = min(y,eyes5);

 y2 = y;
 if( y  < d)
   {
    d=min(y ,d);
    eyes3=eyes2;
    eyes6 = eyes5;
   }
 }   
 p10=o5-=from;
 float  gap2 = .1; 
 p10.z = mod(p10.z + gap2,2. * gap2) - gap2;
 gap2 = .1; 
 p10.x = mod(p10.x + gap2,2. * gap2) - gap2;
       
 vec3 op = p10;
  the = iTime;  
 vec3 op1 = op-vec3(-0.01,-0.02,0.);
   //  op1.y = abs(op1.y)-0.02;
      //   op1.x = abs(op1.x)-0.04;

 vec3 snakesize =vec3(.0000,0,0001.);
 op1 =op1-vec3(cos(o5.z*25.+iTime*.3-pi)*5.,sin(o5.z*30.+iTime*3.-pi)-0.0*4.,0)*0.002;
 vec2 box15 = vec2((dBox(op1-vec3(-0.00,0.000,0.), snakesize)),0.);
 box15.x += cos(o5.z*5.-iTime*1.)*0.002+sin(o5.y*1.-iTime-pi*6.)*.001;
 d=min(d,box15.x);
 g3 +=2./(0.0004+pow(abs(box15.x),1.));
 g2 +=2./(0.0004+pow(abs(eyes3),2.));
 g1 +=2./(0.0004+pow(abs(y2),2.));
 g4 +=1./(0.001+pow(abs(eyes6),1.));


 return d;
}




vec3 normal(vec3 p) {
 vec3 e = vec3(0.0,det,0.0);
 return normalize(vec3(
  de(p+e.yxx)-de(p-e.yxx),
  de(p+e.xyx)-de(p-e.xyx),
  de(p+e.xxy)-de(p-e.xxy)
  )
 );

}




mat2 rot;

vec3 raymarch(in vec3 from, in vec3 dir) 
{
	float t=iTime;
	float cc=cos(t*.03); float ss=sin(t*.03);
    rot=mat2(cc,ss,-ss,cc);
    vec2 lig=vec2(sin(t*2.)*.6,cos(t)*.25-.25);
	float fog,glow,d=1., totdist=glow=fog=0.;
	vec3 p, col=vec3(0.);
	float ref=0.;
	float steps;
	for (int i=0; i<64; i++) {
		if (d>det && totdist<1.5) {
			p=from+totdist*dir;
			d=de(p);
			det=detail*(0.+totdist*5.);
			totdist+=d; 
			glow+=max(0.,.015-d)*exp(-totdist);
			steps++;
		}
	}
	col+=glow*vec3(0.,.9,.8)*.44;
	return col; 
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	tt=iTime*.5;
    vec2 uv = fragCoord.xy / iResolution.xy*2.-1.;
	uv.y*=iResolution.y/iResolution.x;
	vec2 mouse=(iMouse.xy/iResolution.xy-.5);
	float t=iTime*.15;
	float y=(cos(iTime*.2+3.)+1.);
	if (iMouse.z<1.) mouse=vec2(sin(t*3.)*2.,cos(t)+.5)*.04*(.9+y)*min(1.4,iTime*10.);
	uv+=mouse*2.0;
    vec3 from=vec3(sin(iTime)*0.002,3.06,iTime*1.*0.05);
    float the = sin(iTime*.2)*0.5+0.04;
	vec3 dir=normalize(vec3(uv*.85,.5));
    //dir.xy *= mat2(cos(the), -sin(the), sin(the), cos(the));
    vec3 color=raymarch(from,dir); 
	color=pow(color,vec3(1.6));
	color=mix(vec3(length(color)),color,.2)*.95;
	color*= 3.;
	//glow at the end of the tunnel
	//color *=g4*vec3(.001)*vec3(0.,.5,.0)*.02+0.0;

    color +=g3*vec3(.002)*vec3(0.,1.,.6)*.004+0.0;
	color +=g2*vec3(.001)*vec3(.0,.04,.0)*.02+0.0;
	color +=g1*vec3(.001)*vec3(0.0,.1,.3)*.003+0.0;
color+=vec3(.2,.8,.35)*pow(max(0.,.25-length(uv-vec2(0.,.03)))/.3,1.5)*.65;

	fragColor = vec4(color,1.);
}

