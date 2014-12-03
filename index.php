<?php 
$token=md5('123456');
$_SESSION['access_token']=$token; 
if(!isset($_SESSION['userid']))
{
	//header('location:/');
	//exit();
}
?>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
<title>软装网络科技研究院</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<link href="/style/css/style.css" rel="stylesheet" type="text/css">
<link href="/style/css/header.css" rel="stylesheet" type="text/css">
<link href="/style/css/login.css" rel="stylesheet" type="text/css">
<link href="/style/css/index.css" rel="stylesheet" type="text/css">
<script type="text/javascript" src="/style/js/jquery.js"></script>
<script type="text/javascript" src="/style/js/jquery.form.js"></script>
<link href="style/css/nalert.css" rel="/stylesheet" type="text/css">
<script type="text/javascript" src="/style/js/nalert.js"></script>

	<head>
		<title>ImageTool Prototype</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		<style type="text/css" media="screen">
		
		html {
		  height: 100%;
		  overflow: hidden; /* Hides scrollbar in IE */
		}
		 
		body {
		  height: 100%;
		  margin: 0;
		  padding: 0;
		  background-color:#CCD;
		}
		 
		#flashcontent {
		  height: 100%;
		}

		</style>
		
		<script type="text/javascript" src="js/swfobject.js"></script>
		<script type="text/javascript">
		var params = {
			menu: "false",
			scale: "exactFit",
			allowFullscreen: "true",
			allowScriptAccess: "always",
			bgcolor: "#FFFFFF",
			wmode: "direct" // can cause issues with FP settings & webcam
		};
		var attributes = {
			id:"main-demo"
		};
		var flashvars = {
		httpURL:"http://symspace.e360.cn/",token:"<?=$token?>",utoken:"<?=$token?>"
		};
		//alert("token = "+"<?=$token?>");
		swfobject.embedSWF(	"Preloader.swf",
							"flashContentInner", "100%", "100%", "11.2.0",
							null,
							flashvars, params, attributes);
        </script>

	</head>

	<body>
	<script type="text/javascript">
$(function()
{
	if(window.innerHeight != undefined)
	{			
		var bheight=window.innerHeight;
	}
	else
	{			
		var bheight=$(window).height();
	}
	
	/*****弹窗***/

	$(".lay").click(function()
	{
		 $("#brg").css("display","block");
		 $("#showdiv").css("display","block");
		 func.zzcShow();
	 });
	 
	 $("#close").click(function()
	 {
		$("#brg").css("display","none");
		$("#showdiv").css("display","none");
		func.zzcHide();
	 });
	 
	 var func = 
	 {
		 zzcShow:function()
		 {
			  $('.zzc').fadeIn().height(bheight);
		 },
		 zzcHide:function()
		 {
			 $('.zzc').fadeOut();
		 }
	 }
	 
	   
	  /*登录*/	  
      $(".lay-login").stop().click(function()
	  {
		   $("#brg").css("display","block");
		   $("#showdiv-login").css("display","block");
		   func.zzcShow();
	   });
	   $("#close-login").click(function()
	   {
	       $("#brg").css("display","none");
		   $("#showdiv-login").css("display","none");
		   func.zzcHide();
	   });	   
	
      $(".login-name").hover(function(){
		   $(this).addClass("login-name-curr");
		   $(".login-name span").addClass("smjt2");
		   $(".login-name span").removeClass("smjt1");
		   $("#brg").css("display","block");
		   $(".login-show").css("display","block");		  
	   }, function() {
			$(this).removeClass("login-name-curr");
			$(".login-show").css("display","none");
			$(".login-name span").removeClass("smjt2");
	   });
	   $(".login-show").hover(function(){
		   $(".login-name").addClass("login-name-curr");
		   $(".login-show").css("display","block");
		   $(".login-name span").removeClass("smjt1");
		   $(".login-name span").addClass("smjt2");		 
	   }, function() {
			$(".login-name").removeClass("login-name-curr");
			$(".login-show").css("display","none");
			$(".login-name span").removeClass("smjt2");
			$(".login-name span").addClass("smjt1");
	   });
	   
	   /******注册****/
	   $('.btn').stop().click(function(){
			var k=false;
			if($('#email').val() == ''){
				show_err_msg('请输入帐号！');
				k=true;
			}else if($('#email').val() == '输入帐号'){
				show_err_msg('请输入帐号！');
				k=true;
			}else if($('#password').val() == ''){
				show_err_msg('请输入密码！');
				k=true;
			}else if($('#password').val() == '输入密码'){
				show_err_msg('请输入密码！');
				k=true;
			}else if($('#new_pwd').val() == ''){
				show_err_msg('请输入新密码！');
				k=true;
			}else if($('#new_pwd').val() == '再次输入密码'){
				show_err_msg('请输入新密码！');
				k=true;
			}else if($('#password').val() != $('#tran_pw').val()){
				show_err_msg('两次密码输入不一致！');	
				k=true;
			}else{
				var u = $('#username').val();
				var p = $('#password').val();
				$.post('?c=designer&m=reg&a=login&n=designer',{username:u, password:p},function(data){
					nalert(data,'?a=designer&c=setting');					
				});	
			}
		});
		
		/******登录****/
		$('.btn-login').stop().click(function(){
			var k=false;
			if($('#email-login').val() == ''){
				show_err_msg('请输入帐号！');
				k=true;
			}else if($('#email-login').val() == '输入帐号'){
				show_err_msg('请输入帐号！');
				k=true;
			}else if($('#pw-login').val() == '输入密码'){
				show_err_msg('请输入密码！');
				k=true;
			}else if($('#pw-login').val() == ''){
				show_err_msg('请输入密码！');
				k=true;
			}else{
				var u = $('#email-login').val();
				var p = $('#pw-login').val();
				if ($("input[name='remember']:checked").size() == 0) {
					var r = 0;
				}else{
					var r = 1;
				}
				$.post('?c=designer&m=ilogin&a=login&n=home',{username:u, password:p, remember:r, isvcode:false},function(data){
					nalert(data,'?a=designer&c=setting');					
				});	
			}
		});	
})
</script>
<div class="top-nav w100" style="margin-bottom:0">
	<div class="w1200 top-nav-main">
    			<div class="top-nav-lf fl">
			<a href="http://symspace.e360.cn/">首页</a>
            <a href="?n=home&amp;a=product&amp;c=product">产品中心</a>
			<a href="?n=home&amp;a=scheme">方案资源</a>
            <a href="?n=home&amp;a=scheme&amp;c=match">搭配资源</a>
            <a href="?n=home&amp;a=scheme&amp;c=photo">家居灵感</a>
            <a href="?c=flash&amp;a=product&amp;n=home">搭配设计</a>
            <a href="">平面设计</a>
            <a href="http://symspace.e360.cn/ppt/" target="_blank">方案制作</a>
		</div>
        		<div class="top-nav-rt fr">
			<a class="login-name"><span class="smjt1">niu</span></a>
            <div class="login-show">
                <div class="login-info">
                    <a href="?c=setting&amp;a=designer" class="bt">个人信息</a>
                    <a href="?c=cases&amp;t=scheme&amp;a=designer">作品集</a>
                    <a href="?c=scheme&amp;a=designer">我的方案</a>
                    <a href="?c=match&amp;a=designer">我的搭配</a>
                    <a href="?c=house&amp;a=designer">我的户型图</a>
                    <a href="?c=photo&amp;a=designer">我的资料</a>
                    <a href="?c=favorite&amp;a=designer" class="bt">收藏夹</a>
         
                    <a href="?c=designer&amp;m=logout&amp;a=login&amp;n=home">退出</a>
               </div>
            </div>
		</div>
        <div class="per-center fr">
        	<form action="" method="post">
    <input type="text" value="输入关键字搜索" class="page_search" onFocus="if (value =='输入关键字搜索'){value =''}" onBlur="if (value ==''){value='输入关键字搜索'}" name="keyword"> 
    <input type="submit" value="" class="per_serch_button">
</form>        </div>
	</div>
</div>
<div id="software">
		<div id="flashContent">

			<div id="flashContentInner"></div>

		</div>
</div>
		<script type="text/javascript">
$(function(){
	var winHeight = $(window).height();
	$('#software').css('height', (winHeight - 42) + 'px');
});
</script>
	</body>

</html>


