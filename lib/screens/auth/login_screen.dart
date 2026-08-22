import 'dart:math';
import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';

enum AccountRole { user, business }
enum AuthMode { login, signUp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AccountRole? _role;
  AuthMode _mode = AuthMode.login;
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _black,
    body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _role == null
      ? _RolePicker(onPick: (role) => setState(() => _role = role))
      : _AuthPage(role: _role!, mode: _mode, onBack: () => setState(() => _role = null), onModeChanged: (mode) => setState(() => _mode = mode)))),
  );
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.onPick}); final ValueChanged<AccountRole> onPick;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Spacer(), const Text('VOLTEZ', style: TextStyle(color: _cyan, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2)), const Text('AI MOBILITY OS  /  ACCESS PORTAL', style: _micro), const SizedBox(height: 56),
    const Text('HOW DO YOU MOVE?', style: TextStyle(color: _white, fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 10), const Text('Choose your control room to continue.', style: TextStyle(color: _muted)), const SizedBox(height: 28),
    _RoleCard(icon: Icons.person_rounded, title: 'I am a user', detail: 'Find, charge and move smarter.', color: _cyan, onTap: () => onPick(AccountRole.user)), const SizedBox(height: 14),
    _RoleCard(icon: Icons.storefront_rounded, title: 'I am a business owner', detail: 'Operate chargers, fleet and insights.', color: _lime, onTap: () => onPick(AccountRole.business)), const Spacer(), const Center(child: Text('SECURE ACCESS  •  PRIVATE BY DESIGN', style: _micro)),
  ]));
}
class _RoleCard extends StatelessWidget { const _RoleCard({required this.icon,required this.title,required this.detail,required this.color,required this.onTap}); final IconData icon; final String title,detail; final Color color; final VoidCallback onTap;
 @override Widget build(BuildContext context) => InkWell(onTap:onTap,borderRadius:BorderRadius.circular(20),child:Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:color.withValues(alpha:.38))),child:Row(children:[Icon(icon,color:color,size:30),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:_white,fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(detail,style:const TextStyle(color:_muted))])),Icon(Icons.arrow_forward_rounded,color:color)]))); }

class _AuthPage extends StatefulWidget { const _AuthPage({required this.role,required this.mode,required this.onBack,required this.onModeChanged}); final AccountRole role; final AuthMode mode; final VoidCallback onBack; final ValueChanged<AuthMode> onModeChanged; @override State<_AuthPage> createState()=>_AuthPageState(); }
class _AuthPageState extends State<_AuthPage> { final _form=GlobalKey<FormState>(); final _name=TextEditingController(),_email=TextEditingController(),_password=TextEditingController(),_confirm=TextEditingController(),_captcha=TextEditingController(); late int _a,_b;
 @override void initState(){super.initState();_newCaptcha();} void _newCaptcha(){_a=Random().nextInt(8)+2;_b=Random().nextInt(8)+1;} @override void dispose(){for(final c in [_name,_email,_password,_confirm,_captcha]){c.dispose();}super.dispose();}
 @override Widget build(BuildContext context){final signUp=widget.mode==AuthMode.signUp;final accent=widget.role==AccountRole.user?_cyan:_lime;return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[IconButton(onPressed:widget.onBack,icon:const Icon(Icons.arrow_back_rounded,color:_white)),const SizedBox(height:18),Text(widget.role==AccountRole.user?'MOBILITY MEMBER':'MOBILITY OPERATOR',style:_micro.copyWith(color:accent)),const SizedBox(height:8),Text(signUp?'Create your account':'Welcome back.',style:const TextStyle(color:_white,fontSize:29,fontWeight:FontWeight.w900)),const SizedBox(height:22),Row(children:AuthMode.values.map((m)=>Expanded(child:Padding(padding:EdgeInsets.only(right:m==AuthMode.login?8:0),child:OutlinedButton(onPressed:()=>widget.onModeChanged(m),style:OutlinedButton.styleFrom(foregroundColor:m==widget.mode?accent:_muted,side:BorderSide(color:m==widget.mode?accent:const Color(0xFF27404F))),child:Text(m==AuthMode.login?'LOG IN':'SIGN UP'))))).toList()),const SizedBox(height:24),Form(key:_form,child:Column(children:[if(signUp)...[_field(_name,'Full name',Icons.person_outline),const SizedBox(height:12)],_field(_email,'Email address',Icons.alternate_email,email:true),const SizedBox(height:12),_field(_password,'Password',Icons.lock_outline,secret:true),if(signUp)...[const SizedBox(height:12),_field(_confirm,'Confirm password',Icons.lock_reset_outlined,secret:true,confirm:true)],const SizedBox(height:12),Row(children:[Expanded(child:_field(_captcha,'What is $_a + $_b?',Icons.shield_outlined,captcha:true)),IconButton(onPressed:()=>setState(_newCaptcha),icon:const Icon(Icons.refresh_rounded,color:_cyan))]),if(!signUp)Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const _ForgotPassword())),child:const Text('Forgot password?',style:TextStyle(color:_cyan)))),SizedBox(width:double.infinity,height:54,child:FilledButton(onPressed:_submit,style:FilledButton.styleFrom(backgroundColor:accent,foregroundColor:_black),child:Text(signUp?'CREATE ACCOUNT':'ENTER VOLTEZ')))]))]));}
 Widget _field(TextEditingController c,String label,IconData icon,{bool email=false,bool secret=false,bool confirm=false,bool captcha=false})=>TextFormField(controller:c,obscureText:secret,keyboardType:email?TextInputType.emailAddress:null,style:const TextStyle(color:_white),decoration:InputDecoration(prefixIcon:Icon(icon,color:_muted),hintText:label,hintStyle:const TextStyle(color:_muted),filled:true,fillColor:_panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)),validator:(v){if(v==null||v.trim().isEmpty)return 'This field is required';if(email&&!v.contains('@'))return 'Enter a valid email';if(confirm&&v!=_password.text)return 'Passwords do not match';if(captcha&&v!='${_a+_b}')return 'Incorrect captcha';return null;});
 void _submit(){if(!(_form.currentState?.validate()??false))return;Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(_)=>widget.role==AccountRole.business?const DashboardScreen():const _UserHome()));}}
class _ForgotPassword extends StatelessWidget { const _ForgotPassword(); @override Widget build(BuildContext c)=>Scaffold(backgroundColor:_black,appBar:AppBar(backgroundColor:Colors.transparent,foregroundColor:_white),body:const Padding(padding:EdgeInsets.all(24),child:Text('Reset password\n\nEnter your registered email and we will send a secure reset link.',style:TextStyle(color:_white,fontSize:22,height:1.5)))); }
class _UserHome extends StatelessWidget { const _UserHome(); @override Widget build(BuildContext c)=>const Scaffold(backgroundColor:_black,body:Center(child:Text('USER MOBILITY HOME',style:TextStyle(color:_white,fontSize:22,fontWeight:FontWeight.w900)))); }
const _black=Color(0xFF05090E),_panel=Color(0xFF0D1821),_cyan=Color(0xFF50F5FF),_lime=Color(0xFFC9FF58),_white=Color(0xFFF1F8FF),_muted=Color(0xFF7990A1); const _micro=TextStyle(color:_muted,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:1.2);
