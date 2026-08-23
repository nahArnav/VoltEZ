import 'dart:math' as math;
import 'package:flutter/material.dart';

const holoBg = Color(0xFF070B12);
const holoSurface = Color(0xFF111827);
const holoCyan = Color(0xFF22D3EE);
const holoBlue = Color(0xFF3B82F6);
const holoEmerald = Color(0xFF10B981);
const holoText = Color(0xFFF8FAFC);
const holoMuted = Color(0xFF94A3B8);

class HolographicEv extends StatelessWidget {
  const HolographicEv({super.key, required this.progress, this.compact = false});
  final double progress;
  final bool compact;
  @override Widget build(BuildContext context) => AspectRatio(aspectRatio: 1.55, child: LayoutBuilder(builder: (_, box) => Stack(alignment: Alignment.center, children: [
    CustomPaint(size: Size(box.maxWidth, box.maxHeight), painter: _EvPainter(progress)),
    if (!compact) ...[
      _Telemetry(alignment: const Alignment(-.95, -.7), title: 'BATTERY', value: '94%', color: holoEmerald),
      _Telemetry(alignment: const Alignment(.95, -.63), title: 'RANGE', value: '412 km', color: holoCyan),
      _Telemetry(alignment: const Alignment(.9, .74), title: 'CHARGE', value: '122 kW', color: holoBlue),
    ],
  ])));
}
class _Telemetry extends StatelessWidget { const _Telemetry({required this.alignment,required this.title,required this.value,required this.color}); final Alignment alignment; final String title,value; final Color color;
 @override Widget build(BuildContext c)=>Align(alignment:alignment,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:holoBg.withValues(alpha:.72),borderRadius:BorderRadius.circular(7),border:Border.all(color:color.withValues(alpha:.45))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(color:holoMuted.withValues(alpha:.8),fontSize:7,fontWeight:FontWeight.w800,letterSpacing:1)),Text(value,style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.w800))]))); }
class _EvPainter extends CustomPainter { const _EvPainter(this.t); final double t;
 @override void paint(Canvas c,Size s){final center=Offset(s.width*.5,s.height*.52),scale=s.width/360; final radar=Paint()..color=holoCyan.withValues(alpha:.1*t)..style=PaintingStyle.stroke..strokeWidth=1.2*scale;for(var i=0;i<3;i++)c.drawCircle(center,(52+i*31+t*13)%120*scale,radar); final glow=Paint()..maskFilter=MaskFilter.blur(BlurStyle.normal,18*scale)..color=holoCyan.withValues(alpha:.18);c.drawOval(Rect.fromCenter(center:center+Offset(0,50*scale),width:210*scale,height:22*scale),glow);
 final body=Path()..moveTo(center.dx-130*scale,center.dy+24*scale)..quadraticBezierTo(center.dx-108*scale,center.dy-5*scale,center.dx-63*scale,center.dy-11*scale)..quadraticBezierTo(center.dx-25*scale,center.dy-61*scale,center.dx+54*scale,center.dy-56*scale)..quadraticBezierTo(center.dx+95*scale,center.dy-14*scale,center.dx+128*scale,center.dy+7*scale)..lineTo(center.dx+137*scale,center.dy+31*scale)..lineTo(center.dx-137*scale,center.dy+31*scale)..close();
 final fill=Paint()..shader=LinearGradient(colors:[holoBlue.withValues(alpha:.35),holoCyan.withValues(alpha:.12),holoEmerald.withValues(alpha:.25)]).createShader(Rect.fromCenter(center:center,width:280*scale,height:110*scale));c.drawPath(body,fill);final line=Paint()..color=holoCyan.withValues(alpha:.9)..style=PaintingStyle.stroke..strokeWidth=1.5*scale;c.drawPath(body,line);
 final glass=Path()..moveTo(center.dx-70*scale,center.dy-12*scale)..quadraticBezierTo(center.dx-25*scale,center.dy-52*scale,center.dx+48*scale,center.dy-47*scale)..lineTo(center.dx+78*scale,center.dy-10*scale)..close();c.drawPath(glass,Paint()..color=holoCyan.withValues(alpha:.12));c.drawPath(glass,line);
 for(final x in [-82.0,82.0]){final p=center+Offset(x*scale,28*scale);c.drawCircle(p,27*scale,Paint()..color = holoBg..style=PaintingStyle.fill);c.drawCircle(p,28*scale,Paint()..color = holoEmerald.withValues(alpha:.55+.3*math.sin(t*math.pi))..style=PaintingStyle.stroke..strokeWidth=2*scale);c.drawCircle(p,12*scale,Paint()..color = holoCyan.withValues(alpha:.45));}
 final energy=Paint()..color = holoEmerald.withValues(alpha:.8)..strokeWidth=2*scale;c.drawLine(center+Offset(-92*scale,14*scale),center+Offset(92*scale,14*scale),energy); c.drawCircle(center+Offset(130*scale,2*scale),5*scale,Paint()..color = holoEmerald.withValues(alpha:.7+.3*math.sin(t*math.pi*3)));
 }
 @override bool shouldRepaint(covariant _EvPainter old)=>old.t!=t; }
