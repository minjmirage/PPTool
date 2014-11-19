package  {
	import com.adobe.images.JPGEncoder;
	import com.adobe.crypto.MD5;
	import com.greensock.loading.core.DisplayObjectLoader;
	import flash.display.StageDisplayState;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.DataEvent;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filters.DropShadowFilter;
	import flash.filters.GlowFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.net.navigateToURL;
	import flash.net.SharedObject;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	import flash.ui.Mouse;
	import org.alivepdf.pages.Page;
	import org.alivepdf.layout.Size;
	import org.alivepdf.layout.Orientation;
	import org.alivepdf.pdf.PDF;
	import org.alivepdf.saving.Method;
	
	
	[SWF(width = "800", height = "600", frameRate = "30")];
			
	public class PPTool extends Sprite
	{
		public static var baseUrl:String = "http://symspace.e360.cn/";
		
		public var saveId:String = "";		// id of the current saved project
		public var userId:int = 0;
		public var userToken:String = null;
		public var properties:ProjProperties = null;
		
		public var main:MovieClip = null;
		
		public static var utils:MenuUtils = null;
		private var LHS:LHSMenu = null;
		private var RHS:RHSMenu = null;
		private var sliderBar:Sprite = null;
		private var topBar:Sprite = null;
		
		private var undoStk:Array = [];
		private var redoStk:Array = [];
		
		private var target:Image = null;			// current focus
		private var arrow:Arrow = null;
		private var mouseDownT:int = 0;
		private var prevMousePt:Point = null;
		
		private var picResizeUI:Sprite = null;
		public var canvas:Sprite = null;			// the sprite containing all the page contents
		private var arrowsLayer:Sprite = null;
		private var textLayer:Sprite = null;
		private var paper:Sprite = null;			// the thingy blow the canvas
		
		private var disableClick:Boolean = false;	// prevents clicking on stuff behind popup
		
		private var keyShift:Boolean = false;
		
		//=============================================================================
		// 
		//=============================================================================
		public function PPTool() 
		{
			stage.scaleMode = "noScale";
			stage.align = "topLeft";
			
			// ----- draws the light blue bg
			graphics.beginFill(0xCCCCCC,1);
			graphics.drawRect(0,0,5000,4000);
			graphics.endFill();
			
			// ----- bind main loop
			addEventListener(Event.ENTER_FRAME,enterFrameHandler);
			
			// ----- 
			paper = new Sprite();
			setPaperRatio("4:3");
			paper.filters = [new DropShadowFilter(2,45,0x000000)];
			addChild(paper);
			
			// ----- create the center drawing canvas -----------
			canvas = new Sprite();
			canvas.buttonMode = true;
			addChild(canvas);
			canvas.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
			canvas.stage.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
			canvas.stage.addEventListener(MouseEvent.MOUSE_MOVE,mouseMoveHandler);
			canvas.stage.addEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
			stage.addEventListener(KeyboardEvent.KEY_DOWN,keyDownHandler);
			stage.addEventListener(KeyboardEvent.KEY_UP,keyUpHandler);
			
			arrowsLayer = new Sprite();
			canvas.addChild(arrowsLayer);
			textLayer = new Sprite();
			canvas.addChild(textLayer);
			
			// ----- the main UI
			main = new MainMc();
			addChild(main);			
			
			utils = new MenuUtils(stage);	// init convenience utils 
			
			LHS = new LHSMenu();
			LHS.canvas.y = main.L.t.height;
			addChild(LHS.canvas);
			properties = LHS.projProperties;
			
			
			// ----- create the picture transform controls ------
			picResizeUI = new Sprite();
			picResizeUI.addChild(new IcoImageSide());
			picResizeUI.addChild(new IcoImageSide());
			picResizeUI.addChild(new IcoImageSide());
			picResizeUI.addChild(new IcoImageSide());
			picResizeUI.addChild(new IcoImageCorner());
			picResizeUI.addChild(new IcoImageCorner());
			picResizeUI.addChild(new IcoImageCorner());
			picResizeUI.addChild(new IcoImageCorner());
			picResizeUI.addChild(new CursorSymbols());
			(MovieClip)(picResizeUI.getChildAt(picResizeUI.numChildren - 1)).gotoAndStop(1);
			
			picResizeUI.buttonMode = true;
			picResizeUI.filters = [new GlowFilter(0x001133, 1, 2,2, 1)];
			
			// ----- create magnification slider -------------------
			sliderBar = createHSlider(function(sc:Number):void 
			{
				sc = (0.5*(1-sc)+2*sc);
				canvas.scaleX = canvas.scaleY = sc;
				paper.scaleX = paper.scaleY = sc;
			},103);
			sliderBar.x = 36;
			sliderBar.y = 16;
			main.B.l.addChild(sliderBar);
			
			// ----- specifies UI button listeners
			topBar = main.T;
			main.T.l.addEventListener(MouseEvent.CLICK,function(ev:Event):void 
			{
				if (main.T.l.b1.hitTestPoint(stage.mouseX,stage.mouseY))		// show file menu
				{
					var s:Sprite = showFileOptions();
					s.x = main.T.l.b1.x+main.T.l.x+main.T.x;
					s.y = main.T.l.b1.y+main.T.l.b1.height;
					//showSaveLoad(function():void {disableClick=false;});
				}
				else if (main.T.l.b2.hitTestPoint(stage.mouseX,stage.mouseY))	// details
				{
					showProjectProperties();
				}
				else if (main.T.l.b3.hitTestPoint(stage.mouseX,stage.mouseY))	// 
				{
					showItemsList();
				}
				else if (main.T.l.b4.hitTestPoint(stage.mouseX,stage.mouseY))	// 
				{
					showSlideShow();
				}
				else if (main.T.l.b5.hitTestPoint(stage.mouseX,stage.mouseY))	// 
				{
					if (stage.displayState!=StageDisplayState.FULL_SCREEN)
						stage.displayState = StageDisplayState.FULL_SCREEN;
					else
						stage.displayState = StageDisplayState.NORMAL;
				}
				else if (main.T.l.b6.hitTestPoint(stage.mouseX,stage.mouseY))	// undo
				{	
					trace("undo");
					if (undoStk.length>1)
					{
						redoStk.push(undoStk.pop());
						//prn(undoStk[undoStk.length-1]);
						restoreFromData(undoStk[undoStk.length-1]);
					}
				}
				else if (main.T.l.b7.hitTestPoint(stage.mouseX,stage.mouseY))	// redo
				{
					trace("redo");
					if (redoStk.length>0)
					{
						undoStk.push(redoStk.pop());
						restoreFromData(undoStk[undoStk.length-1]);
					}
				}
			});
			main.T.r.addEventListener(MouseEvent.CLICK,function(ev:Event):void 
			{
				if (main.T.r.b1.hitTestPoint(stage.mouseX,stage.mouseY))		// add text
				{
					addText();
				}
				else if (main.T.r.b2.hitTestPoint(stage.mouseX, stage.mouseY))	// add colored squares
				{
					var hexColor:String = "#12345678";
					var img:Image = new Image(hexColor, hexColor, new BitmapData(100, 100, false, parseInt(hexColor.split("#")[1],16)));
					LHS.selected.Pics.push(img);					// add image to Page
					
					mouseMoveFn = function():void 	// start drag
					{
						img.centerTo(canvas.mouseX,canvas.mouseY);
					}
					
					updateCanvas();
				}
				else if (main.T.r.b4.hitTestPoint(stage.mouseX, stage.mouseY))	// add arrow
				{
					trace("add arrow");
					arrow = new Arrow();
					LHS.selected.Arrows.push(arrow);					// add image to Page
					updateCanvas();
					var s:String = getCurState();
					if (undoStk[undoStk.length-1]!=s) 
					{
						trace("push curState="+s);
						undoStk.push(s);
						updatePageImage();
					}
				}
			});
			main.B.r.addEventListener(MouseEvent.CLICK,function(ev:Event):void 
			{
				if (main.B.r.b1.hitTestPoint(stage.mouseX,stage.mouseY))		// set bg
				{
					showSetAsBackground();
				}
				else if (main.B.r.b2.hitTestPoint(stage.mouseX,stage.mouseY))	// upload user image
				{
					userSelectAndUploadImage();
				}
			});
			
			if (root.loaderInfo.parameters.httpURL!=null) baseUrl = root.loaderInfo.parameters.httpURL+"";	// why the F$%$ this doesnt work
			if (root.loaderInfo.parameters.token!=null) userToken = root.loaderInfo.parameters.token+"";
			if (baseUrl.charAt(baseUrl.length - 1) != "/")	baseUrl += "/";
			
			//addChild(utils.createText("baseUrl="+baseUrl+"  userToken="+userToken));
			
			// ----- function to exec after got userToken
			function initAfterLogin():void
			{
				// ----- the RHS menu -------------------------------
				RHS = new RHSMenu(userToken,getProductItemsData);
				addChild(RHS.canvas);	// above canvas and paper
				prevW = 0;
				RHS.clickCallBack = function (img:Image):void 
				{
					trace("RHS.clickCallBack");
					img.centerTo(canvas.mouseX,canvas.mouseY);
					addImage(img);
					mouseMoveFn = function():void 	// start drag
					{
						img.centerTo(canvas.mouseX,canvas.mouseY);
					}
					mouseUpFn = function():void
					{
						mouseUpFn = null;
						mouseMoveFn = null;
						if (paper.hitTestPoint(stage.mouseX,stage.mouseY)==false)
						{
							trace("removed image not on paper");
							if (LHS.selected.Pics.indexOf(img)!=-1)
								LHS.selected.Pics.splice(LHS.selected.Pics.indexOf(img),1);
						}
						updateCanvas();
					}
				}
				RHS.updateCanvas = updateCanvas;
			}
			
			
			if (userToken==null)
			{
				// ----- force user to login ----------------------------
				var loginPage:Sprite = createLoginPage(function():void 
				{
					if (loginPage.parent!=null) loginPage.parent.removeChild(loginPage); 
					initAfterLogin();
				});
				addChild(loginPage);
			}
			else
			{
				initAfterLogin();
			}
			/*
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=login&c=user");
			req.method = "post";  
			var vars : URLVariables = new URLVariables();  
			vars.username = "shaoyiting";  
			vars.password = "shaoyiting";  
			req.data = vars;
			ldr.load(req);
			ldr.addEventListener(Event.COMPLETE, onComplete);  
			function onComplete(e : Event):void
			{  
				var o:Object = JSON.parse(ldr.data);
				if (o.meta.code==200)
				{
					userId = o.data.userid;
					userToken = o.data.utoken;
					trace("userToken="+userToken);
					initAfterLogin();
				}
			}
			*/
			undoStk.push(getCurState());	// save default blank state
		}//endconstr
		
		//=============================================================================
		// change between 4:3 and 16:9
		//=============================================================================
		private function setPaperRatio(r:String):void
		{
			if (r=="4:3")
			{
				paper.graphics.clear();
				paper.graphics.beginFill(0xFFFFFF,1);
				paper.graphics.drawRect(-800/2,-600/2,1024,768);	// 4:3 ratio
				paper.graphics.endFill();
			}
			else if (r=="16:9")
			{
				paper.graphics.clear();
				paper.graphics.beginFill(0xFFFFFF,1);
				paper.graphics.drawRect(-960/2,-540/2,1280,720);	// 4:3 ratio
				paper.graphics.endFill();
			}
		}//endfunction
		
		//=============================================================================
		// grey out and disables click interractions, returns remove disable function
		//=============================================================================
		private function disableInterractions(alp:Number=0.8):Function
		{
			disableClick = true;
			var s:Sprite = new Sprite();
			
			var prevWH:Point = new Point();
			function resizeHandler(ev:Event):void
			{
				if (prevWH.x != stage.stageWidth || prevWH.y != stage.stageHeight)
				{
					s.graphics.clear();
					s.graphics.beginFill(0x000000,alp);
					s.graphics.drawRect(0,0,stage.stageWidth,stage.stageHeight);
					s.graphics.endFill();
					prevWH.x = stage.stageWidth;
					prevWH.y = stage.stageHeight;
				}
			}//endfunction
			resizeHandler(null);
			s.addEventListener(Event.ENTER_FRAME,resizeHandler);
			
			function remove():void
			{
				disableClick = false;
				s.removeEventListener(Event.ENTER_FRAME, resizeHandler);
				if (s.parent!=null) s.parent.removeChild(s);
			}
			
			addChild(s);
			
			return remove;
		}//endfunction
		
		//=============================================================================
		// gets the userId and userToken
		//=============================================================================
		private function createLoginPage(callBack:Function=null):MovieClip
		{
			var login:MovieClip = new PopLogin();
			login.x = (stage.stageWidth-login.width)/2;
			login.y = (stage.stageHeight-login.height)/2;
			login.graphics.beginFill(0x000000,0.8);
			login.graphics.drawRect(-login.x,-login.y,stage.stageWidth,stage.stageHeight);
			login.graphics.endFill();
			
			var tff:TextFormat = login.usernameTf.defaultTextFormat;
			tff.color = 0x999999;
			login.usernameTf.setTextFormat(tff);
			login.passwordTf.setTextFormat(tff);
			login.usernameTf.type = "input";
			login.passwordTf.type = "input";
			
			function keyHandler(event:KeyboardEvent):void
			{
				// if the key is ENTER
				if(event.charCode == 13)
				{
					if (login.usernameTf.text!="" && login.passwordTf.text!="")
					{
						var ldr:URLLoader = new URLLoader();
						var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=login&c=user");
						req.method = "post";  
						var vars : URLVariables = new URLVariables();  
						vars.username = login.usernameTf.text;  
						vars.password = login.passwordTf.text;  
						req.data = vars;
						ldr.load(req);
						ldr.addEventListener(Event.COMPLETE, onComplete);  
						function onComplete(e : Event):void
						{  
							trace("login return="+ldr.data);
							var o:Object = JSON.parse(ldr.data);
							login.textTf.text = o.meta.message; 
							if (o.meta.code==200)
							{
								userId = o.data.userid;
								userToken = o.data.utoken;
								if (callBack!=null) callBack();
							}
						}
					}
				}
			}//endfunction
			
			function focusHandler(ev:Event):void
			{
				(TextField)(ev.target).text = "";
			}
			login.usernameTf.addEventListener(FocusEvent.FOCUS_IN,focusHandler);
			login.passwordTf.addEventListener(FocusEvent.FOCUS_IN,focusHandler);
			login.usernameTf.addEventListener(KeyboardEvent.KEY_DOWN,keyHandler);
			login.passwordTf.addEventListener(KeyboardEvent.KEY_DOWN,keyHandler);
			
			return login;
		}//endfunction
		
		//=============================================================================
		// align the UI regions
		//=============================================================================
		private var prevW:int=0;
		private var prevH:int=0;
		public function chkAndResize():void
		{
			var sw:int = stage.stageWidth;
			var sh:int = stage.stageHeight;
			if (target!=null) main.P.visible = true; else main.P.visible = false;
			
			if (prevW==sw && prevH==sh) return;
			
			trace("chkAndResize sw,sh="+sw+","+sh+"   prevW,prevH="+prevW+","+prevH);
			prevW = sw;
			prevH = sh;
			  
			main.R.x = sw-main.R.width;
			main.T.r.x = sw - main.L.width - main.R.width-main.T.r.width+1;
			main.T.m.width = sw - main.T.l.width - main.T.r.width - main.L.width - main.R.width+1;
			main.P.m.width = sw - main.L.width - main.R.width - main.P.l.width;
			main.L.m.height = sh - main.L.t.height - main.L.b.height;
			main.L.b.y = sh - main.L.b.height;
			main.R.m.height = sh - main.R.t.height - main.R.b.height+2;
			main.R.b.y = sh - main.R.b.height;
			main.B.y = sh - main.B.height;
			main.B.r.x = sw - main.L.width - main.R.width - main.B.r.width;
			main.B.m.width = sw - main.L.width - main.R.width - main.B.l.width - main.B.r.width;
			
			LHS.canvas.y = main.L.t.height;
			LHS.resize(sh-main.L.t.height-main.L.b.height);
			if (RHS!=null)
			{
				RHS.canvas.x = main.R.x-25;
				trace("RHS.canvas.x="+RHS.canvas.x);
				RHS.canvas.y = main.R.t.height;
				RHS.resize(sh-main.R.t.height);
			}
			
		}//endfunction
		
		//=============================================================================
		// lets user select pages to generate PDF with
		//=============================================================================
		private function showGenPDF():Sprite
		{
			var enableI:Function = disableInterractions();
			
			var s:MovieClip = new PagePDF();
			s.x = (stage.stageWidth - s.width) / 2;
			s.y = (stage.stageHeight - s.height) / 2;
			
			var con:Sprite = new Sprite();
			con.x = s.msk1.x;
			con.y = s.msk1.y;
			con.mask = s.msk1;
			s.addChild(con);
			
			function createTab(title:String,color:uint,selCallBack:Function):Sprite
			{
				var tab:Sprite = new Sprite();
				tab.graphics.beginFill(color, 1);
				tab.graphics.drawRect(0, 0, s.msk1.width - 18, 30);
				tab.graphics.endFill();
				var plabel:TextField = utils.createText(title);
				plabel.x = 35;
				plabel.y = (tab.height-plabel.height)/2
				tab.addChild(plabel);
				var pradio:MovieClip = utils.createRadioButton(new ChkBox(), function(state:int):void {selCallBack(state); } );
				pradio.gotoAndStop(2);
				pradio.x = tab.width - pradio.width - 10;
				pradio.y = (tab.height - pradio.height) / 2;
				tab.addChild(pradio);
				tab.x = 2;
				tab.y = yOff;
				yOff += tab.height + 2;
				con.addChild(tab);
				return tab;
			}//endfunction
			
			function selAllNone(spTabs:Array):Function
			{
				return function(state:int):void 
				{
					for (var i:int = 0; i < spTabs.length; i++)
						spTabs[i].getChildAt(spTabs[i].numChildren - 1).gotoAndStop(state + 1);
				}
			}//endfunction
			
			// ----- generate selection tabs ------------------------------------------
			var yOff:int = 2;
			var PagesTabs:Array = [];
			for (var i:int=0; i < LHS.Spaces.length; i++)
			{
				// ----- generate space tab
				var space:Space = LHS.Spaces[i];
				var spTabs:Array = [];
				var stab:Sprite = createTab(space.title, 0xBFC3CE, selAllNone(spTabs));
				
				// ----- generate page tab
				for (var j:int = 0; j < space.Pages.length; j++)
				{
					var ptab:Sprite = createTab("     " + space.Pages[j].title, 0xEBEBED, function(state:int):void { trace("pageTab " + state); } );
					PagesTabs.push(ptab);
					spTabs.push(ptab);
				}
			}
			
			// ----- show thumbnail on right when tab is selected
			var bmp:Bitmap = new Bitmap(new BitmapData(s.msk2.width,s.msk2.height,false,0xFFFFFF));
			s.msk2.addChild(bmp)
			function selectPage(i:int):void
			{
				LHS.selected = LHS.Pages[i];
				var tab:Sprite = PagesTabs[i] as Sprite;
				con.graphics.clear();
				con.graphics.beginFill(0x333333,1);
				con.graphics.drawRect(tab.x-2,tab.y-2,tab.width+4,tab.height+4);
				con.graphics.endFill();
				
				// ----- draw on thumbnail of page ----------------------
				updateCanvas();
				drawCanvasThumb(bmp.bitmapData);
			}//endfunction
			if (LHS.Pages.length>0)	selectPage(0);
			
			// ----- create scrollbar -----------------------------------
			var scroll:Sprite = new Sprite();					// scrollbar for 
			s.addChild(scroll);
			scroll.addChild(new Sprite());
			(Sprite)(scroll.getChildAt(0)).buttonMode = true;
			scroll.graphics.clear();
			var h:int = s.msk1.height - 6;
			LHSMenu.drawStripedRect(scroll,0,0,4,h,0xEEEEEE,0xE6E6E6,5,10);
			scroll.y = s.msk1.y+3;
			scroll.x = s.msk1.x+s.msk1.width-3-4;
			var bh:Number = Math.min(h,h*s.msk1.height/con.height);
			var bar:Sprite = (Sprite)(scroll.getChildAt(0));
			bar.graphics.clear();
			LHSMenu.drawStripedRect(bar,0,0,4,bh,0x333355,0x373757,5,10);
			function startScroll():void
			{
				trace("startScroll");
				bar.startDrag(false, new Rectangle(0, 0, 0, scroll.height - bar.height));
				function enterFrameHandler(ev:Event):void
				{
					con.y = s.msk1.y - bar.y/scroll.height * con.height;
				}//endfunction
				function upHandler(ev:Event):void
				{
					bar.stopDrag();
				}//endfunction
				addEventListener(Event.ENTER_FRAME, enterFrameHandler);
				stage.addEventListener(MouseEvent.MOUSE_UP, upHandler);
			}
			
			// ----- handles select tabs, trigger genPDF close ----------
			function clickHandler(ev:Event):void
			{
				var mx:int = stage.mouseX;
				var my:int = stage.mouseY;
				if (bar.hitTestPoint(mx, my))
					startScroll();
				else if (s.b1.hitTestPoint(mx,my) ||
					s.b2.hitTestPoint(mx,my) ||
					s.bClose.hitTestPoint(mx,my))
				{
					if (s.b1.hitTestPoint(mx,my))
					{
						var flags:String = "";
						for (var i:int = 0; i < PagesTabs.length; i++)
						{
							if (PagesTabs[i].getChildAt(PagesTabs[i].numChildren - 1).currentFrame > 1)
								flags += "1";
							else
								flags += "0";
						}
						generatePDF(flags);
					}
					enableI();
					s.parent.removeChild(s);
					s.removeEventListener(MouseEvent.CLICK, clickHandler);
				}
				else
				{
					for (i=PagesTabs.length-1; i>-1; i--)
						if (s.msk1.hitTestPoint(stage.mouseX,stage.mouseY) && 
							PagesTabs[i].hitTestPoint(stage.mouseX,stage.mouseY))
							selectPage(i);
				}
			}//endfunction
			s.addEventListener(MouseEvent.MOUSE_DOWN, clickHandler);
			
			s.tf.text = "方案名 : "+properties.name+"\n风格 : "+properties.style+"   类型 : "+properties.type+"\n最后编辑时间 : "+properties.lastModify;
			
			addChild(s);
			return s;
		}//endfunction
		
		//=============================================================================
		// gets the userId and userToken
		//=============================================================================
		private function showItemsList(callBack:Function=null):Sprite
		{
			if (saveId=="")
			{
				return null;   
			}
			
			var enableI:Function = disableInterractions();
			
			function createText(txt:String):TextField
			{
				if (txt==null)	txt="null";
				var tf:TextField = new TextField();
				tf.wordWrap = false;
				tf.autoSize = "left";
				var tff:TextFormat = tf.defaultTextFormat;
				tff.size = 13;
				tf.defaultTextFormat = tff;
				tf.htmlText = txt;
				return tf;
			}//endfunction
			
			function createBtn(txt:String):Sprite
			{
				var s:Sprite = new Sprite();
				var tf:TextField = createText(txt);
				tf.mouseEnabled = false;
				tf.x = 5,
				tf.y = 5;
				s.addChild(tf);
				LHSMenu.drawStripedRect(s,0,0,s.width+10,s.height+10,0xCCCCCC,0xC6C6C6,5,0);
				return s;
			}//endfunction
			
			// ----- creates the top labels -------------------------
			var ItmLst:Sprite = new Sprite();	// this is the main sprite
			var labs:Array = "序号,缩略图,名称,型号,品类,规格,材质,颜色,单价,数量,小计".split(",");
			var spacs:Array = " 0,  30,  110, 200,270,340, 420,490,540,600,660".split(",");
			var labSpr:Sprite = new Sprite();
			for (var i:int=0; i<labs.length; i++)
			{
				var tt:TextField = createText(labs[i]);
				tt.x = Number(spacs[i]);
				labSpr.addChild(tt);
			}
			LHSMenu.drawStripedRect(labSpr,0,0,labSpr.width,labSpr.height,0xCCCCCC,0xC6C6C6,5,0);
			labSpr.x = 10;
			labSpr.y = 10;
			ItmLst.addChild(labSpr);
			
			var con:Sprite = new Sprite();	// container for item sprs
			con.x = 10;
			con.y = 10+labSpr.height;
			
			var marg:int = 10;
			
			// ------ create msk and scroll bar -------------------------------
			var msk:Sprite = new Sprite();
			msk.graphics.beginFill(0,1);
			msk.graphics.drawRect(0,0,labSpr.width+80,400);
			msk.graphics.endFill();
			msk.x = 10;
			msk.y = 10+labSpr.height;
			con.mask = msk;
			ItmLst.addChild(msk);
			
			var scrol:Sprite = new Sprite();
			LHSMenu.drawStripedRect(scrol,0,0,marg,400,0xAAAAAA,0xACACAC,5,10);
			scrol.x = labSpr.width+80+marg*2;
			scrol.y = marg + labSpr.height;
			ItmLst.addChild(scrol);
			var bar:Sprite = new Sprite();
			scrol.addChild(bar);
			function startDragHandler(ev:Event):void
			{
				bar.startDrag(false,new Rectangle(0,0,0,scrol.height-bar.height));
			}
			function stopDragHandler(ev:Event):void
			{
				bar.stopDrag();
			}
			bar.addEventListener(MouseEvent.MOUSE_DOWN,startDragHandler);
			stage.addEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
			
			var totalTf:TextField = createText("总计金额： －－ 元， 产品件数：－－件");
			totalTf.x = marg;
			totalTf.y = 400+labSpr.height+35;
			ItmLst.addChild(totalTf);
			
			// ----- changes to given items P ---------------------------------
			function setDisplayList(P:Array):void
			{
				var prevCateId:String = "";
				var totalCost:Number = 0;
				var I:Array = [];
				for (var i:int=0; i<P.length; i++)
				{
					if (P[i].cateid!=prevCateId)
					{
						I.push(["<font size='16'>"+P[i].cateName+"</font>"]);
						prevCateId = P[i].cateid;
					}
					//printProp(P[i]);
					var dat:Array = [i,utils.createThumbnail(baseUrl+P[i].image+P[i].thumb200),P[i].productname,P[i].productsn,P[i].pinglei,P[i].size,P[i].material,P[i].color,P[i].price,1,P[i].price];
					totalCost += Number(P[i].price);
					I.push(dat);
				}
				
				while (con.numChildren>0)	con.removeChildAt(0);
				var yOff:int = 0;
				for (i=0; i<I.length; i++)
				{
					var s:Sprite = new Sprite();
					for (var j:int=0; j<I[i].length; j++)
					{
						if (I[i][j] is Bitmap)
						{
							I[i][j].x = Number(spacs[j]);
							s.addChild(I[i][j]);
						}
						else
						{
							var tf:TextField = createText(I[i][j]);
							tf.x = Number(spacs[j]);
							s.addChild(tf);
						}
					}
					
					if (s.numChildren<3)	
						yOff+= 10;
					else
					{
						s.graphics.lineStyle(0,0x999999);
						s.graphics.drawRect(0,0,labSpr.width+50,s.height);
					}
					s.y = yOff;
					yOff+= s.height;
					con.addChild(s);
				}
				
				totalTf.htmlText = "<font size='15' >总计金额：<font size='17' color='#33AAAA' >"+totalCost+"</font> 元， 产品件数：<font size='17' color='#33AAAA' >"+P.length+"</font> 件</font>";
				
				bar.graphics.clear();
				LHSMenu.drawStripedRect(bar,0,0,marg,Math.min(400,400/con.height*scrol.height),0x333355,0x373757,5,10);
			}//endfunction
						
			// ----- update on changes ----------------------------------------
			function updateHandler(ev:Event):void
			{
				con.y = labSpr.y+labSpr.height-con.height*bar.y/scrol.height;
			}//endfunction
			ItmLst.addEventListener(Event.ENTER_FRAME,updateHandler);
			
			LHSMenu.drawStripedRect(ItmLst,0,0,labSpr.width+80+marg*4,400+labSpr.height+60,0xFFFFFF,0xF6F6F6,5,10);
			ItmLst.x = (stage.stageWidth-ItmLst.width)/2;
			ItmLst.y = (stage.stageHeight-ItmLst.height)/2;
			ItmLst.addChild(con);
			//pageSelector.y = -pageSelector.height-5;
			//ItmLst.addChild(pageSelector);
			
			// ------ to close when clicked outside 
			var coverUp:Sprite = new Sprite();
			coverUp.graphics.beginFill(0x000000,0.8);
			coverUp.graphics.drawRect(0,0,stage.stageWidth,stage.stageHeight);
			coverUp.graphics.endFill();
			addChild(coverUp);
			addChild(ItmLst);
			
			function clickHandler(ev:Event):void
			{
				ItmLst.removeEventListener(Event.ENTER_FRAME,updateHandler);
				bar.removeEventListener(MouseEvent.MOUSE_DOWN,startDragHandler);
				stage.removeEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
				coverUp.removeEventListener(MouseEvent.CLICK,clickHandler);
				coverUp.parent.removeChild(coverUp);
				ItmLst.parent.removeChild(ItmLst);
				enableI();
				if (callBack!=null) callBack();
			}
			coverUp.addEventListener(MouseEvent.CLICK,clickHandler);
			
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=info&id="+saveId+"&token="+userToken);
			ldr.load(req);
			
			// ----- select space to show -------------------------------------
			function createSpaceSelector(spaceObjs:Array,AllProds:Array):Sprite
			{
				var s:Sprite = new Sprite();
				for (var i:int=0; i<spaceObjs.length; i++)
				{
					//printProp(spaceObjs[i]);
					var btn:Sprite = createBtn(spaceObjs[i].spacename);
					btn.x = s.width+5;
					s.addChild(btn);
				}
				
				// ----------
				var dlBtn:Sprite = createBtn("下载");
				dlBtn.x = labSpr.width-dlBtn.width;
				s.addChild(dlBtn);
								
				function clickSelHandler(ev:Event):void
				{
					if (dlBtn.hitTestPoint(stage.mouseX,stage.mouseY))
					{
						navigateToURL(new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=excel&id="+saveId+"&token="+userToken));
					}
				
					var Ids:Array = [];
					for (var i:int=0; i<spaceObjs.length; i++)
					{
						var btn:Sprite = s.getChildAt(i) as Sprite;
						if (btn.hitTestPoint(stage.mouseX,stage.mouseY))
						{
							if (btn.alpha==1)	btn.alpha=0.5;
							else				btn.alpha = 1;
						}
						if (btn.alpha==1) Ids.push(spaceObjs[i].spaceId);
					}
					
					var SelProds:Array = [];
					for (i=0; i<AllProds.length; i++)
						if (Ids.indexOf(AllProds[i].spaceId)>-1)
							SelProds.push(AllProds[i]);
					
					setDisplayList(SelProds);
				}//endfunction
				s.addEventListener(MouseEvent.CLICK,clickSelHandler);
				
				function cleanUpHandler(ev:Event):void
				{
					s.removeEventListener(MouseEvent.CLICK,clickSelHandler);
					s.removeEventListener(Event.REMOVED_FROM_STAGE,cleanUpHandler);
				}
				s.addEventListener(Event.REMOVED_FROM_STAGE,cleanUpHandler);
				
				s.y = -s.height;
				ItmLst.addChild(s);
				
				return s;
			}//endfunction
			
			function printProp(o:Object):void
			{
				for(var id:String in o) 
					trace(id+" : " +o[id]);
			}//endfunction
			
			// ----- when server returns, execute -----------------------------
			function onComplete():void
			{
				var o:Object = JSON.parse(ldr.data);
				trace("showItemsList ldr.data=" + ldr.data);
				if (o.scheme.qdjson == null)	return;
				
				o = JSON.parse(o.scheme.qdjson);
				
				var Products:Array = [];
				var Spaces:Array = [];
				for(var spaceId:String in o) 
				{
					o[spaceId].spaceId = spaceId;				// put spaceId in space data
					var spaceData:Object = o[spaceId].data;
					Spaces.push(o[spaceId]);
					//prn("o[spaceId].catename="+o[spaceId].catename);
					for (var catId:String in spaceData)
					{
						spaceData[catId].catId = catId;			// put catId in cat data
						spaceData[catId].spaceId = spaceId;
						var catData:Object = spaceData[catId].data;
						var cateName:String = spaceData[catId].catename;
						for (var prodId:String in catData)
						{
							catData[prodId].prodId = prodId;
							catData[prodId].catId = catId;			// put catId in cat data
							catData[prodId].spaceId = spaceId;
							catData[prodId].cateName = cateName;
							//printProp(catData[prodId]);
							Products.push(catData[prodId]);
						}
					}//endfor
				}//endfor
			
				// show the items
				setDisplayList(Products);
				
				// show the space slelection
				createSpaceSelector(Spaces,Products);
				
				
			}//endfunction
			ldr.addEventListener(Event.COMPLETE, onComplete);  
						
			return ItmLst;
		}//endfunction
		
		//=============================================================================
		// proj name, style, type, form factor etc
		//=============================================================================
		public function showProjectProperties():Sprite
		{
			function showSels(url:String,defaId:String,px:int=320,py:int=64,w:int=50,vid:String="areaname",callBack:Function=null,selFn:Function=null):void
			{
				var ldr:URLLoader = new URLLoader();
				var req:URLRequest = new URLRequest(url);
				trace(req.url);
				ldr.load(req);
				function onComplete(e:Event):void
				{	// ----- when received data from server
					//trace("ldr.data="+ldr.data);
					var o:Object = JSON.parse(ldr.data);
					var dat:Array = o.data;
					if (dat == null) 
					{
						dat = o.categories;
						while (dat.length > 0 && dat[0][vid] != "风格")		// HACK!!!
							dat.shift();			// to REMOVE all other nonsense....!!
						if (dat.length>0)	dat.shift();
						for (var i:int = 0; i < dat.length && dat[i][vid] != "空间"; i++)	{}
						dat.splice(i, dat.length - i);
					}
					var lst:DisplayObject = null
					if (dat == null || dat.length == 0)
						lst = utils.createInputText(selFn,defaId,w);
					else
					{
						var N:Vector.<String> = new Vector.<String>();
						for (i=0; i<dat.length; i++)	N.push(dat[i][vid]);
						var A:Array = defaId.split("|");
						lst = utils.createDropDownList(N, A.pop(), function(t:String):void 
						{
							if (selFn!=null)
							for (var i:int=0; i < dat.length; i++)
								if (dat[i][vid] == t)
									selFn(dat[i].id+"|"+dat[i][vid]);
						}, w);
					}
					lst.x = px;
					lst.y = py;
					s.addChild(lst);
					if (callBack != null)	callBack();
				}//endfunction
				ldr.addEventListener(Event.COMPLETE, onComplete);  
			}//endfunction
			
			var enableI:Function = disableInterractions();
			
			var nprop:ProjProperties = properties.clone();
			
			var s:MovieClip = new PageInfo();
			s.x = (stage.stageWidth - s.width) / 2;
			s.y = (stage.stageHeight - s.height) / 2;
			
			var drawBase:Sprite = new Sprite();
			s.addChild(drawBase);
			drawBase.graphics.lineStyle(0, 0x666666);
			var tf:TextField = utils.createInputText(function(t:String):void {nprop.name=t;}, properties.name, 200);
			tf.x = 150;
			tf.y = 64;
			s.addChild(tf);
			for (var i:int = s.numChildren - 1; i >= s.numChildren-1; i--)
			{
				var c:DisplayObject = s.getChildAt(i);
				drawBase.graphics.drawRect(c.x,c.y, c.width, c.height);
			}
			
			var lst:Sprite = utils.createDropDownList(Vector.<String>(["4:3","16:9"]),properties.form,function(t:String):void {nprop.form=t; setPaperRatio(t);}, 200);
			lst.x = 150;
			lst.y = 163;
			s.addChild(lst);
			
			showSels(baseUrl + "?n=api&a=scheme&c=scheme&m=cate&token=" + userToken, properties.style, 150, 97, 200, "classname", null, 
			function(id:String):void 
			{
				trace("styleId="+id);
				nprop.style = id;
			});
			
			// ------------------------ !@#$%^&%$#@%^&*(()
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(baseUrl + "?n=api&a=scheme&c=scheme&m=cate&token=" + userToken);
			ldr.load(req);
			function onComplete(e:Event):void
			{	// ----- when received data from server
				var o:Object = JSON.parse(ldr.data);
				var sty:Array = o.categories;
				while (sty.length > 0 && sty[0].classname != "风格")		// HACK!!!
					sty.shift();			// to REMOVE all other nonsense....!!
				if (sty.length>0)	sty.shift();
				for (var i:int = 0; i < sty.length && sty[i].classname != "空间"; i++)	{}
				var typ:Array = [];
				if (i<sty.length) typ = sty.slice(i+1);
				sty.splice(i, sty.length - i);
				
				function makeLst(dat:Array,defaId:String,px:int,py:int,w:int,selFn:Function):void
				{
					var lst:DisplayObject = null
					if (dat == null || dat.length == 0)
						lst = utils.createInputText(selFn,defaId,w);
					else
					{
						var N:Vector.<String> = new Vector.<String>();
						for (i=0; i<dat.length; i++)	N.push(dat[i].classname);
						var A:Array = defaId.split("|");
						lst = utils.createDropDownList(N, A.pop(), function(t:String):void 
						{
							if (selFn!=null)
							for (var i:int=0; i < dat.length; i++)
								if (dat[i].classname == t)
									selFn(dat[i].id+"|"+dat[i].classname);
						}, w);
					}
					lst.x = px;
					lst.y = py;
					s.addChild(lst);
				}//endfunction
				
				makeLst(sty,properties.style, 150, 97, 200,function(id:String):void 
				{
					trace("styleId="+id);
					nprop.style = id;
				});
				makeLst(typ,properties.type, 150, 130, 200,function(id:String):void 
				{
					trace("typeId="+id);
					nprop.type = id;
				});
				
			}//endfunction
			ldr.addEventListener(Event.COMPLETE, onComplete);  
			// ------------------------ !@#$%^&%$#@%^&*(()
			
			function closeHandler(ev:MouseEvent):void
			{
				if (ev.target == s.b1)
				{
					LHS.projProperties = properties = nprop;
					nprop.updateLastModifyDate();
				}
				enableI();
				s.parent.removeChild(s);
				s.b1.removeEventListener(MouseEvent.CLICK, closeHandler);
				s.b2.removeEventListener(MouseEvent.CLICK, closeHandler);
			}//endfunction
			s.b1.addEventListener(MouseEvent.CLICK, closeHandler);
			s.b2.addEventListener(MouseEvent.CLICK, closeHandler);
			
			addChild(s);
			return s;
		}//endfunction
		
		//=============================================================================
		// proj name, style, type, form factor etc
		//=============================================================================
		public function showSaveProperties(callBack:Function):Sprite
		{
			var enableI:Function = disableInterractions();
			
			var nprop:ProjProperties = properties.clone();
			
			var s:MovieClip = new PageSave();
			s.x = (stage.stageWidth - s.width) / 2;
			s.y = (stage.stageHeight - s.height) / 2;
			
			function showSels(url:String,defaId:String,px:int=320,py:int=64,w:int=50,vid:String="areaname",callBack:Function=null,selFn:Function=null):void
			{
				var ldr:URLLoader = new URLLoader();
				var req:URLRequest = new URLRequest(url);
				trace(req.url);
				ldr.load(req);
				function onComplete(e:Event):void
				{	// ----- when received data from server
					//trace("ldr.data="+ldr.data);
					var o:Object = JSON.parse(ldr.data);
					var dat:Array = o.data;
					if (dat == null) 
					{
						dat = o.categories;
						while (dat.length > 0 && dat[0][vid] != "风格")		// HACK!!!
							dat.shift();			// to REMOVE all other nonsense....!!
						if (dat.length>0)	dat.shift();
					}
					for (var i:int = 0; i < dat.length && dat[i][vid] != "空间"; i++)	{}
					dat.splice(i, dat.length - i);
					var lst:DisplayObject = null
					if (dat == null || dat.length == 0)
						lst = utils.createInputText(selFn,defaId,w);
					else
					{
						var N:Vector.<String> = new Vector.<String>();
						for (i=0; i<dat.length; i++)	N.push(dat[i][vid]);
						var A:Array = defaId.split("|");
						lst = utils.createDropDownList(N, A.pop(), function(t:String):void 
						{
							if (selFn!=null)
							for (var i:int=0; i < dat.length; i++)
								if (dat[i][vid] == t)
									selFn(dat[i].id+"|"+dat[i][vid]);
						}, w);
					}
					lst.x = px;
					lst.y = py;
					s.addChild(lst);
					if (callBack != null)	callBack();
				}//endfunction
				ldr.addEventListener(Event.COMPLETE, onComplete);  
			}//endfunction
			
			showSels(baseUrl+"?n=api&a=area&c=area&pid=省id值", properties.sheng, 327, 64, 80, "areaname",null,
			function(pid:String):void 
			{ 
				nprop.sheng = pid;			// the sheng id
				showSels(baseUrl+"?n=api&a=area&c=area&pid="+pid, properties.shi,410, 64, 80, "areaname",null,
				function(pid:String):void 
				{
					nprop.shi = pid;		// the shi id
					showSels(baseUrl+"?n=api&a=area&c=area&pid="+pid, properties.qu, 493, 64, 80, "areaname",null,
					function(pid:String):void 
					{
						nprop.qu = pid;		// the qu id
					}); 
				}); 
			});
			
			var drawBase:Sprite = new Sprite();
			s.addChild(drawBase);
			drawBase.graphics.lineStyle(0, 0x999999);
			
			// ----- left col
			var tf:TextField = utils.createInputText(function(t:String):void {nprop.name=t;}, properties.name, 170);
			tf.x = 100;
			tf.y = 64;
			s.addChild(tf);
					
			// ----- right col
			tf = utils.createInputText(function(t:String):void {nprop.address=t;},properties.address, 240);
			tf.x = 327;
			tf.y = 97;
			s.addChild(tf);
			tf = utils.createInputText(function(t:String):void {nprop.project=t;},properties.project, 100);
			tf.x = 327;
			tf.y = 130;
			s.addChild(tf);
			tf = utils.createInputText(function(t:String):void {nprop.serial=t;},properties.serial, 60);
			tf.x = 440;
			tf.y = 130;
			s.addChild(tf);
			tf = utils.createInputText(function(t:String):void {nprop.area=t;},properties.area, 50);
			tf.x = 517;
			tf.y = 130;
			s.addChild(tf);
			tf = utils.createInputText(function(t:String):void {nprop.details=t;},properties.details, 240);
			tf.x = 327;
			tf.y = 163;
			s.addChild(tf);
			
			// ----- draw boxes
			for (var i:int = s.numChildren - 1; i >= s.numChildren - 6; i--)
			{
				var c:DisplayObject = s.getChildAt(i);
				drawBase.graphics.drawRect(c.x,c.y, c.width, c.height);
			}
			
			// ----- left col
			var lst:Sprite = utils.createDropDownList(Vector.<String>(["4:3", "16:9"]), properties.form,
			function(t:String):void {nprop.form=t; setPaperRatio(t);}, 170);
			lst.x = 100;
			lst.y = 163;
			s.addChild(lst);
			
			// ------------------------ !@#$%^&%$#@%^&*(()
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(baseUrl + "?n=api&a=scheme&c=scheme&m=cate&token=" + userToken);
			ldr.load(req);
			function onComplete(e:Event):void
			{	// ----- when received data from server
				var o:Object = JSON.parse(ldr.data);
				var sty:Array = o.categories;
				while (sty.length > 0 && sty[0].classname != "风格")		// HACK!!!
					sty.shift();			// to REMOVE all other nonsense....!!
				if (sty.length>0)	sty.shift();
				for (var i:int = 0; i < sty.length && sty[i].classname != "空间"; i++)	{}
				var typ:Array = [];
				if (i<sty.length) typ = sty.slice(i+1);
				sty.splice(i, sty.length - i);
				
				function makeLst(dat:Array,defaId:String,px:int,py:int,w:int,selFn:Function):void
				{
					var lst:DisplayObject = null
					if (dat == null || dat.length == 0)
						lst = utils.createInputText(selFn,defaId,w);
					else
					{
						var N:Vector.<String> = new Vector.<String>();
						for (i=0; i<dat.length; i++)	N.push(dat[i].classname);
						var A:Array = defaId.split("|");
						lst = utils.createDropDownList(N, A.pop(), function(t:String):void 
						{
							if (selFn!=null)
							for (var i:int=0; i < dat.length; i++)
								if (dat[i].classname == t)
									selFn(dat[i].id+"|"+dat[i].classname);
						}, w);
					}
					lst.x = px;
					lst.y = py;
					s.addChild(lst);
				}//endfunction
				
				makeLst(sty,properties.style, 100, 97, 170,function(id:String):void 
				{
					trace("styleId="+id);
					nprop.style = id;
				});
				makeLst(typ,properties.type, 100, 130, 170,function(id:String):void 
				{
					trace("typeId="+id);
					nprop.type = id;
				});
				
			}//endfunction
			ldr.addEventListener(Event.COMPLETE, onComplete);  
			// ------------------------ !@#$%^&%$#@%^&*(()
			
			
			function closeHandler(ev:MouseEvent):void
			{
				if (ev.target == s.b1)
				{
					LHS.projProperties = properties = nprop;
					nprop.updateLastModifyDate();
				}
				if (callBack!=null) callBack(ev.target == s.b1);
				enableI();
				s.parent.removeChild(s);
				s.b1.removeEventListener(MouseEvent.CLICK, closeHandler);
				s.b2.removeEventListener(MouseEvent.CLICK, closeHandler);
			}//endfunction
			s.b1.addEventListener(MouseEvent.CLICK, closeHandler);
			s.b2.addEventListener(MouseEvent.CLICK, closeHandler);
			
			addChild(s);
			return s;
		}//endfunction
		
		//=============================================================================
		// show menu to new,load,save,save to PDF etc
		//=============================================================================
		public function showFileOptions():Sprite
		{
			var enableI:Function = disableInterractions(0);
			var labels:Vector.<String> = Vector.<String>(["新建", "打开", "保存", "另存为", "公开", "生成 PDF"]);
			var fns:Vector.<Function> = Vector.<Function>([	function():void			// new file
															{
																cleanUp();
																clearAll();
																showProjectProperties();
																saveId = "";
															},
															function():void			// list files to load
															{
																showSaveFiles();
																cleanUp();
															},
															function():void			// save/ override
															{
																showSaveProperties(function(saveIt:Boolean):void
																{
																	trace("saveIt="+saveIt);
																	if (saveIt)
																		saveToServer("incognito",saveToSharedObject);
																	cleanUp();
																});
															},
															function():void			// save as new
															{
																showSaveProperties(function(saveIt:Boolean):void
																{
																	trace("saveIt="+saveIt);
																	if (saveIt)
																	{
																		saveId = null;		
																		saveToServer("incognito",saveToSharedObject);
																	}
																	cleanUp();
																});
															},
															function():void			// publicise
															{
																s.visible = false;
																var cs:Sprite = utils.createChoices("公开这个方案？",
																	Vector.<String>(["确定","取消"]),
																	Vector.<Function>([function():void 
																				{
																					var ldr:URLLoader = new URLLoader();
																					function onComplete(ev:Event):void
																					{
																						trace("share response: "+ldr.data);
																					}//endfunction
																					ldr.addEventListener(Event.COMPLETE, onComplete);
																					ldr.load(new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=share&id="+saveId+"&token="+userToken));
																					if (cs.parent != null) cs.parent.removeChild(cs);
																					s.visible = true;
																					cleanUp();
																				},
																				function():void  
																				{
																					if (cs.parent != null) cs.parent.removeChild(cs);
																					s.visible = true;
																				}]));
																cs.x = s.x;
																cs.y = s.y;
																cs.filters = [new DropShadowFilter(3, 45, 0x000000)];
																addChild(cs);
															},
															function():void
															{
																showGenPDF();
																cleanUp();  
															},])
			
			if (saveId == "")
			{
				labels.splice(3, 2);
				fns.splice(3, 2);
			}
			var s:Sprite = utils.createChoices(	"文件",labels,fns);
			function cleanUp():void 
			{	// function to remove this menu cleanly
				if (s.parent != null) s.parent.removeChild(s);
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, chkCloseHandler);
				enableI();
			}
			function chkCloseHandler(ev:Event):void
			{	// function to close when click elsewhere
				if (s.hitTestPoint(stage.mouseX, stage.mouseY))
					return;
				cleanUp();
			}
			stage.addEventListener(MouseEvent.MOUSE_DOWN, chkCloseHandler);
			
			s.filters = [new DropShadowFilter(3, 45, 0x000000)];
			addChild(s);
			return s;
		}//endfunction
		
		//=============================================================================
		// show options to set selected image as background
		//=============================================================================
		public function showSetAsBackground():void
		{
			var enableI:Function = disableInterractions(0);
			function cleanUp():void
			{
				target = null;
				s.parent.removeChild(s); 
				enableI();
				updateCanvas();
			}
			var s:Sprite = 
			utils.createChoices("设背景图",
								Vector.<String>(["设为页面背景图","设为空间背景图","设为全部背景图"]),
								Vector.<Function>([	function():void {setTargetAsBg(0); cleanUp();},
													function():void {setTargetAsBg(1); cleanUp();},
													function():void {setTargetAsBg(2); cleanUp();}]),130);
			function chkCloseHandler(ev:Event):void
			{
				if (s.hitTestPoint(stage.mouseX, stage.mouseY))
					return;
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, chkCloseHandler);
				enableI();
				if (s.parent != null) 
					s.parent.removeChild(s);
			}
			stage.addEventListener(MouseEvent.MOUSE_DOWN, chkCloseHandler);
			s.y = main.B.y - s.height;
			s.x = main.B.r.x+main.B.x;
			s.filters = [new DropShadowFilter(3, 45, 0x000000)];
			addChild(s);
		}//endfunction
		
		//=============================================================================
		// show list of save files to load
		//=============================================================================
		public function showSaveFiles():void
		{
			var enableI:Function = disableInterractions();
			
			var Btns:Vector.<Sprite> = new Vector.<Sprite>();
		
			// --------------------------------------------------------------------
			function makeBtn(ico:DisplayObject,txt:String):void
			{
				var btn:Sprite = new Sprite();
				btn.graphics.beginFill(0xFFFFFF,1);
				btn.graphics.drawRoundRect(0,0,100,100,10);
				btn.graphics.endFill();
				ico.x = (btn.width-ico.width)/2;
				ico.y = (btn.height-ico.height)/2;
				btn.addChild(ico);
				var tf:TextField = new TextField();
				tf.autoSize = "left";
				tf.wordWrap = false;
				var tff:TextFormat = tf.defaultTextFormat;
				tff.color = 0x000000;
				tff.size = 14;
				tf.defaultTextFormat = tff;
				tf.text = txt;
				tf.y = (btn.height-tf.height)/2;
				tf.x = btn.width+5;
				btn.addChild(tf);
				Btns.push(btn);
			}
			
			// --------------------------------------------------------------------
			function createMenu(projects:Array):void
			{
				var men:Sprite = new IconsMenu(Btns, 5, 1, function(idx:int):void // creates icons menu
				{	// options clicked callback
					men.visible = false;
					var choi:Sprite = 
					utils.createChoices("文档", 
											Vector.<String>(["打开","删除","取消"]), 
											Vector.<Function>([function():void 
											{
												var so:SharedObject = SharedObject.getLocal("ImageTool");
												var saveDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
												saveId = projects[idx].id;
												trace("open "+saveId);
												restoreFromData(projects[idx].data);	// imports the data string
												closeMen();
												choi.parent.removeChild(choi);
											},
											function():void 
											{
												var so:SharedObject = SharedObject.getLocal("ImageTool");
												var savDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
												savDat.splice(idx * 3, 3);	// deletes the data
												so.data.savedData = savDat;
												so.flush();
												closeMen();
												var ldr:URLLoader = new URLLoader();
												function onComplete(ev:Event):void
												{
													trace("project "+projects[idx].id+" removed: "+ldr.data);
													ldr.removeEventListener(Event.COMPLETE, onComplete);
												}
												ldr.addEventListener(Event.COMPLETE, onComplete);
												
												ldr.load(new URLRequest(baseUrl + "?n=api&a=scheme&c=scheme&m=del&idx=" + projects[idx].id + "&token=" + userToken));
												choi.parent.removeChild(choi);
											},
											function():void 
											{
												men.visible = true;
												choi.parent.removeChild(choi);
											}]), 100);
					choi.x = (stage.stageWidth - choi.width) / 2;
					choi.y = (stage.stageHeight - choi.height) / 2;
					addChild(choi);
					
				});
				function closeMen():void 
				{
					stage.removeEventListener(MouseEvent.MOUSE_DOWN, chkCloseHandler);
					enableI();
					if (men.parent != null) 
						men.parent.removeChild(men);
				}
				function chkCloseHandler(ev:Event):void
				{
					if (men.hitTestPoint(stage.mouseX, stage.mouseY))	return;
					closeMen();
				}
				stage.addEventListener(MouseEvent.MOUSE_DOWN, chkCloseHandler);
				men.x = (stage.stageWidth - men.width) / 2;
				men.y = (stage.stageHeight - men.height) / 2;
				addChild(men);
			}
			
			// ----- get project saves from server
			function onComplete(ev:Event):void
			{
				var projects:Array = JSON.parse(ldr.data).projects;
				trace("listSavedFiles:\n"+prnObject(projects));
					
				var so:SharedObject = SharedObject.getLocal("ImageTool");
				var saveDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
				if (saveDat==null)	saveDat = [];
				
				var idx:int=0;
				function loadNext():void
				{
					function _andNext(ico:DisplayObject):void
					{
						makeBtn(ico,projects[idx].name);	// create button with icon and label
						idx++;
						if (idx>=projects.length)
							createMenu(projects);
						else
							loadNext();
					}//endfunction
					
					if (saveDat.length > idx * 3 + 1)
					{
						var ldr:Loader = new Loader();
						function imgLoaded(ev:Event):void	
						{
							ldr.contentLoaderInfo.removeEventListener(Event.COMPLETE, imgLoaded);
							_andNext(ldr.content);
						}
						ldr.loadBytes(saveDat[idx*3+1] as ByteArray);
						ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, imgLoaded);
					}
					else
					{
						_andNext(new Bitmap(new BitmapData(100,100,false,0xFF0000)));
					}
				}//endfunction
				
				if (projects.length > idx)	
					loadNext();		// strat load and show savefiles
				else	// if no save files 
				{
					var men:Sprite = utils.createChoices("没有文档", 
														Vector.<String>(["确认"]), 
														Vector.<Function>([function():void 
														{
															enableI();
															if (men.parent != null) 
																men.parent.removeChild(men);
														}]), 100);
					men.x = (stage.stageWidth - men.width) / 2;
					men.y = (stage.stageHeight - men.height) / 2;
					addChild(men);
				}
			}//endfunction
			var ldr:URLLoader = new URLLoader();
			ldr.addEventListener(Event.COMPLETE, onComplete);
			ldr.load(new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=index&token="+userToken));
		}//endfunction
		
		//=============================================================================
		// a simple pages slide show function, scrolls left right
		//=============================================================================
		public function showSlideShow():void
		{
			var ww:int = paper.width / paper.scaleX;
			var hh:int = paper.height / paper.scaleY;
			
			var Slides:Vector.<Bitmap> = new Vector.<Bitmap>();
			var con:Sprite = new Sprite();
			for (var i:int=0; i<LHS.Pages.length; i++)
			{
				var bmp:Bitmap = null;
				if (LHS.Pages[i].image==null)
				{
					LHS.selected = LHS.Pages[i];
					updateCanvas();
					bmp = new Bitmap(new BitmapData(ww,hh,false,0xFFFFFF));
					drawCanvasThumb(bmp.bitmapData);
				}
				else
					bmp = new Bitmap(LHS.Pages[i].image);
				Slides.push(bmp);
				con.addChild(bmp);
			}//endfor
			
			var enableI:Function = disableInterractions();
			var s:Sprite = new Sprite();
			s.addChild(con);
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			s.addChild(tf);
			
			var idx:int = 0;
			function enterFrameHandler(Ev:Event):void
			{
				for (var i:int = 0; i < con.numChildren;  i++)
				{
					var pic:DisplayObject = con.getChildAt(i);
					var sc:Number = Math.min(stage.stageWidth * 3 / 4 / ww, stage.stageHeight * 3 / 4 / hh);
					pic.scaleX = sc;
					pic.scaleY = sc;
					pic.x = stage.stageWidth * i;
				}
				
				con.x = (con.x * 3 + ((stage.stageWidth-bmp.width)/2-idx*stage.stageWidth))/4;
				con.y = (stage.stageHeight - con.height) / 2;
				
				tf.htmlText = "<font color='#9999Ff' size='40'>" + (idx+1) + "</font><font color='#FFFFFF'>/" + LHS.Pages.length+"</font>";
				tf.x = (stage.stageWidth - tf.width) / 2;
				tf.y = stage.stageHeight - tf.height - 5;
			}//endfunction
			
			function clickHandler(ev:Event):void
			{
				if (stage.mouseY > stage.stageHeight * 3 / 4 || stage.mouseY < stage.stageHeight * 1 / 4 )
				{
					stage.removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
					stage.removeEventListener(MouseEvent.MOUSE_DOWN, clickHandler);
					s.parent.removeChild(s);
					enableI();
				}
				else if (stage.mouseX < stage.stageWidth / 2 && idx>0)
					idx--;
				else if (stage.mouseX > stage.stageWidth / 2 && idx < LHS.Pages.length - 1)
					idx++;
			}//endfunction
			
			stage.addEventListener(Event.ENTER_FRAME, enterFrameHandler);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, clickHandler);
			
			addChild(s);
		}//endfunction
		
		//=============================================================================
		// uploads selected asset to the server
		//=============================================================================
		public function userSelectAndUploadImage():void
		{
			var enableI:Function = disableInterractions();
			
			var fileRef:FileReference = new FileReference(); 
			fileRef.addEventListener(Event.SELECT, onFileSelected); 
			fileRef.addEventListener(Event.CANCEL, onCancel); 
			fileRef.addEventListener(IOErrorEvent.IO_ERROR, onIOError); 
			fileRef.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError); 
			fileRef.addEventListener(ProgressEvent.PROGRESS, onProgress); 
			fileRef.addEventListener(Event.COMPLETE, onComplete); 
			var textTypeFilter:FileFilter = new FileFilter("Image Files (*.jpg, *.png)","*.jpg;*.png"); 
			fileRef.browse([textTypeFilter]); 
			
			function onFileSelected(evt:Event):void 	{fileRef.load();}//endfunction
			
			function onComplete(evt:Event):void 
			{ 
				fileRef.removeEventListener(Event.COMPLETE, onComplete); 
				var uploadBtn:Sprite = null;
				var cancelBtn:Sprite = null;
				var loader:Loader = new Loader();
				loader.loadBytes(fileRef.data);
				function remove(upload:Boolean=false):void
				{
					if (upload) 
					{
						fileRef.upload(new URLRequest(baseUrl + "?n=api&a=scheme&c=scheme_pic&m=add&schemeid=" + saveId + "token=" + userToken));
						function receivedResponse(ev:DataEvent):void
						{
							trace("upload response data:" + ev.data);
							var o:Object = JSON.parse(ev.data+"");
							MenuUtils.loadAsset(baseUrl+o.data.pic,function(pic:Bitmap):void
							{
								if (pic == null)
								{
									trace("Error! failed to load uploaded pic!!");
									return;
								}
								addImage(new Image(o.data.pic,o.data.pic,pic.bitmapData));
								updateCanvas();
							});
							
							fileRef.removeEventListener(DataEvent.UPLOAD_COMPLETE_DATA, receivedResponse);
						}
						fileRef.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, receivedResponse);
					}
					if (uploadBtn != null)	uploadBtn.parent.removeChild(uploadBtn);
					if (cancelBtn != null)	cancelBtn.parent.removeChild(cancelBtn);
					loader.content.parent.removeChild(loader.content);
					enableI();
				}
				function loadComplete(ev:Event):void
				{
					loader.contentLoaderInfo.removeEventListener(Event.COMPLETE,loadComplete);
					var sc:Number = Math.min(1,stage.stageWidth*0.75/loader.content.width,stage.stageHeight*0.75/loader.content.height);
					loader.content.scaleX = sc;
					loader.content.scaleY = sc;
					loader.content.x = (stage.stageWidth - loader.content.width)/2;
					loader.content.y = (stage.stageHeight - loader.content.height)/2;
					addChild(loader.content);
					uploadBtn = utils.createTextButton("上传", function():void {remove(true);} );
					cancelBtn = utils.createTextButton("取消", function():void { remove(); } );
					uploadBtn.x = stage.stageWidth / 2 - uploadBtn.width - 10;
					uploadBtn.y = stage.stageHeight - uploadBtn.height - 10;
					cancelBtn.x = stage.stageWidth / 2 + uploadBtn.width - 10;
					cancelBtn.y = stage.stageHeight - uploadBtn.height - 10;
					addChild(uploadBtn);
					addChild(cancelBtn);
				}
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE,loadComplete);
			}//endfunction
			
			function onProgress(evt:ProgressEvent):void {trace("Loaded " + evt.bytesLoaded + " of " + evt.bytesTotal + " bytes.");} 
			function onCancel(evt:Event):void 			{trace("The browse request was canceled by the user.");} 
			function onIOError(evt:IOErrorEvent):void 	{trace("There was an IO Error.");}
			function onSecurityError(evt:Event):void  	{trace("There was a security error.");}
		}//endfunction
		
		//=============================================================================
		// Main loop
		//=============================================================================
		private var prevLHSSelected:Page = null;
		private function enterFrameHandler(ev:Event):void
		{
			// ----- switch page
			if (LHS.selected!=prevLHSSelected)
			{
				prevLHSSelected = LHS.selected;
				target = null;
				updateCanvas();
			}
			
			canvas.x = stage.stageWidth/2+(main.L.width-main.R.width)/2;
			canvas.y = stage.stageHeight/2+(main.T.height-main.B.height)/2;
			paper.x = canvas.x;
			paper.y = canvas.y;
			
			chkAndResize();
			
			//prn("Mem:"+System.totalMemory);
		}//endfunction
		
		//=============================================================================
		// start pic transform and move, skew if clicked
		//=============================================================================
		private function mouseDownHandler(ev:Event=null):void
		{
			var mX:int = canvas.stage.mouseX;
			var mY:int = canvas.stage.mouseY;
			
			// ----- return if hits UI elements -------------------------------
			if (disableClick ||
				main.T.hitTestPoint(mX, mY) || 
				main.B.hitTestPoint(mX, mY) || 
				main.L.hitTestPoint(mX, mY) || 
				main.R.hitTestPoint(mX, mY) || 
				sliderBar.hitTestPoint(mX, mY))
				return;
			
			if (arrow!=null && arrow.canvas.hitTestPoint(mX,mY)) arrow.onMouseDown();
			
			mouseDownT = getTimer();
			prevMousePt = new Point(canvas.mouseX, canvas.mouseY);
			var page:Page = LHS.selected;
			
			// ----- find text being clicked ----------------------------------
			for (var i:int=page.Txts.length-1; i>-1; i--)
				if (page.Txts[i].hitTestPoint(mX, mY))
				{
					editText(page.Txts[i]);
					return;
				}
			
			if (target == null) return;
			
			// ----- if pics top bar functions clicked ------------------------
			if (main.P.l.hitTestPoint(mX, mY))
			{
				if (main.P.l.b1.hitTestPoint(mX, mY))		// TOP LAYER
				{
					page.Pics.splice(page.Pics.indexOf(target), 1);
					page.Pics.push(target);
				}
				else if (main.P.l.b2.hitTestPoint(mX, mY))	// MOVE UP
				{
					if (page.Pics.indexOf(target)<page.Pics.length-1)
					{
						var uidx:int = page.Pics.indexOf(target);
						page.Pics[uidx] = page.Pics[uidx+1];
						page.Pics[uidx+1] = target;
					}
				}
				else if (main.P.l.b3.hitTestPoint(mX, mY))	// MOVE DOWN
				{
					if (page.Pics.indexOf(target)>0)
					{
						var didx:int = page.Pics.indexOf(target);
						page.Pics[didx] = page.Pics[didx-1];
						page.Pics[didx-1] = target;
					}
				}
				else if (main.P.l.b4.hitTestPoint(mX, mY))	// BOTTOM LAYER
				{
					page.Pics.splice(page.Pics.indexOf(target), 1);
					page.Pics.unshift(target);
				}
				else if (main.P.l.b5.hitTestPoint(mX, mY))	// GROUP
				{
					 if (page.Pics.indexOf(target)==-1)	// ----- group pics not in page
					{
						var I:Vector.<Image> = (GroupImage)(target).Images;
						var gidx:int = 0;
						for (var k:int = I.length - 1; k > -1; k-- )
						{
							if (gidx < page.Pics.indexOf(I[k]))	// remove children pics from page
								gidx = page.Pics.indexOf(I[k]);
							page.Pics.splice(page.Pics.indexOf(I[k]), 1);
						}
						page.Pics.splice(gidx, 0, target);	// add grp pic to page
					}
				}
				else if (main.P.l.b6.hitTestPoint(mX, mY))	// UNGROUP
				{
					if (page.Pics.indexOf(target) != -1)	// grp pic in page
					{
						var gidx:int = page.Pics.indexOf(target);
						page.Pics.splice(gidx, 1);			// remove grp pic
						I = (GroupImage)(target).Images;
						for (k = I.length - 1; k > -1; k-- )	// add children pics
							page.Pics.splice(gidx, 0, I[k]);
					}
				}
				else if (main.P.l.b7.hitTestPoint(mX, mY))	// TRASH
				{
					page.Pics.splice(page.Pics.indexOf(target),1);
					target = null;
				}
				else if (main.P.l.b8.hitTestPoint(mX, mY))	// LOCK
				{
					
				}
				else if (main.P.l.b9.hitTestPoint(mX, mY))	// CROP
				{
					if (!(target is CropImage))
					{
						var cImg:CropImage = new CropImage(target);
						page.Pics.splice(page.Pics.indexOf(target),1,cImg);
						target = cImg;
					}
					var enableI:Function = disableInterractions();
					(CropImage)(target).doCropUI(canvas,function():void {enableI(); updateCanvas();});
				}
			}
			
			// ----- if pic controls clicked ----------------------------------
			var csr:MovieClip = (MovieClip)(picResizeUI.getChildAt(picResizeUI.numChildren - 1));	// the follow cursor
			if (picResizeUI.hitTestPoint(mX, mY,true))
			{
				for (i=picResizeUI.numChildren-1; i>-1; i--)
				{
					var e:Sprite = (Sprite)(picResizeUI.getChildAt(i));
					if (e.hitTestPoint(mX, mY))
					{
						if (!e.visible)
						{
							// do nothing
						}
						else if (e is IcoImageSide)		// ----- scale side 
						{
							var cpt:Point = target.getCenter();
							var ico:Sprite = e;
							mouseMoveFn = function():void 
							{
								var v:Point = new Point(ico.x,ico.y).subtract(cpt);
								var u:Point = v.clone();
								u.normalize(1);
								var mv:Point = new Point(canvas.mouseX-cpt.x,canvas.mouseY-cpt.y);
								var sc:Number = (mv.x*u.x + mv.y*u.y)/v.length;		// side scaling 
								for (var i:int=target.Corners.length-1; i>-1; i--)
								{
									var cv:Point = target.Corners[i].subtract(cpt);
									if (cv.x*u.x+cv.y*u.y>0)
									{
										target.Corners[i].x+=v.x*(sc-1);
										target.Corners[i].y+=v.y*(sc-1);
									}
									else
									{
										target.Corners[i].x-=v.x*(sc-1);
										target.Corners[i].y-=v.y*(sc-1);
									}
								}
								target.updateBranch();		// refresh for groupImage
							}//endfunction
						}
						else if (e is IcoImageCorner)	// ----- move corner
						{
							var corner:Point = null;
							for (i=target.Corners.length-1; i>-1; i--)
								if (corner==null || target.Corners[i].subtract(prevMousePt).length<corner.subtract(prevMousePt).length)
									corner = target.Corners[i];	// allow dragging of points
								
							mouseMoveFn = function():void 
							{
								corner.x = canvas.mouseX;
								corner.y = canvas.mouseY;
								target.updateBranch();		// refresh for groupImage
							}//endfunction
						}
					}
				}//endfor
				
				// ----- if clicked follow csr 
				if (csr.visible)
				{
					if (csr.currentFrame==1)		// dragging cursor
					{
						var off:Point = target.getCenter().subtract(new Point(canvas.mouseX,canvas.mouseY));
						mouseMoveFn = function():void 
						{	
							target.centerTo(canvas.mouseX+off.x,canvas.mouseY+off.y);
						}//endfunction
					}
					else if (csr.currentFrame==2)	// scaling cursor
					{
						var prevScale:Number = 1;
						mouseMoveFn = function():void 		// ----- rotate image
						{	
							var cpt:Point = target.getCenter();
							var mpt:Point = new Point(canvas.mouseX,canvas.mouseY);
							var va:Point = prevMousePt.subtract(cpt);
							var vb:Point = mpt.subtract(cpt);
							var val:Number = va.length;
							var vbl:Number = vb.length;
							if (!isNaN(vbl/val)) target.scale((vbl/val)/prevScale);
							prevScale=vbl/val;
						}//endfunction
					}
				}//endfunction
			}
			else 
			{
				if (csr.currentFrame==3)	// rotating cursor
				{
					var prevAng:Number = 0;
					mouseMoveFn = function():void 		// ----- rotate image
					{	
						var cpt:Point = target.getCenter();
						var mpt:Point = new Point(canvas.mouseX,canvas.mouseY);
						var va:Point = prevMousePt.subtract(cpt);
						var vb:Point = mpt.subtract(cpt);
						var val:Number = va.length;
						var vbl:Number = vb.length;
						if (val==0 || vbl==0) return;
						va.x/=val; va.y/=val;
						vb.x/=vbl; vb.y/=vbl;
						var ang:Number = Math.acos(Math.max(-1,Math.min(1,va.x*vb.x+va.y*vb.y)));
						if (keyShift)	
							ang = Math.round(ang*16/(Math.PI*2))/(16/(Math.PI*2)); 
						var dir:Number = va.x*vb.y - va.y*vb.x;
						if (dir>0)	ang*=-1;
						target.rotate(ang-prevAng);
						prevAng = ang;
					}//endfunction
				}
			}
			
			updateCanvas();
		}//endfunction
		
		//=============================================================================
		// 
		//=============================================================================
		private	var mouseMoveFn:Function = null;
		private function mouseMoveHandler(ev:Event=null):void
		{
			if (mouseMoveFn!=null)
			{
				mouseMoveFn();
				updateCanvas();
			}
			// ----- draws selection box
			else if (prevMousePt != null)
			{
				main.graphics.clear();
				main.graphics.lineStyle(0, 0, 0.5);
				main.graphics.drawRect(	canvas.x + prevMousePt.x*canvas.scaleX, 
										canvas.y + prevMousePt.y*canvas.scaleY, 
										(canvas.mouseX - prevMousePt.x)*canvas.scaleX, 
										(canvas.mouseY - prevMousePt.y)*canvas.scaleY);
				main.graphics.lineStyle();
			}
			
			// ----- position picResizeUI mouse cursor
			if (target != null)
			{
				var curPt:Point = new Point(canvas.mouseX, canvas.mouseY);
				var csr:MovieClip = (MovieClip)(picResizeUI.getChildAt(picResizeUI.numChildren - 1));
				if (pointInPoly(curPt, target.Corners))
				{
					csr.visible = true;
					if (mouseMoveFn==null) csr.gotoAndStop(1);
					for (var i:int=target.Corners.length-1;  i>-1; i--)
					{
						var sub:Point = target.Corners[i].subtract(curPt);
						if (mouseMoveFn==null && sub.length < 15)	csr.gotoAndStop(2);
					}
				}
				else
				{
					csr.visible = false;
					for (i=target.Corners.length-1;  i>-1; i--)
					{
						sub = target.Corners[i].subtract(curPt);
						if (sub.length<15)
						{
							csr.visible = true;
							if (mouseMoveFn==null) csr.gotoAndStop(3);
						}
					}
				}
				if (csr.visible)
				{
					for (i=picResizeUI.numChildren-2; i>-1; i--)
						if (picResizeUI.getChildAt(i).hitTestPoint(stage.mouseX,stage.mouseY))
							csr.visible = false;
					if (main.T.hitTestPoint(stage.mouseX, stage.mouseY) || 
						main.B.hitTestPoint(stage.mouseX, stage.mouseY) || 
						main.L.hitTestPoint(stage.mouseX, stage.mouseY) || 
						main.R.hitTestPoint(stage.mouseX, stage.mouseY))
						csr.visible = false;
				}
				if (csr.visible)
				{
					if (disableClick==false) Mouse.hide();
					csr.x = picResizeUI.mouseX;
					csr.y = picResizeUI.mouseY;
					if (csr.currentFrame==1)	csr.rotation = 0;
					else		
					{
						var cpt:Point = target.getCenter();
						csr.rotation = 180/Math.PI*Math.atan2(csr.x-cpt.x,-csr.y+cpt.y);
					}
				}
				else
				{
					Mouse.show();
					csr.x = 0;
					csr.y = 0;
				}
			}
			if (picResizeUI.parent == null) Mouse.show();
		}//endfunction
		
		//=============================================================================
		// 
		//=============================================================================
		private	var mouseUpFn:Function = null;
		private function mouseUpHandler(ev:Event=null):void
		{
			var mX:int = stage.mouseX;
			var mY:int = stage.mouseY;
			
			// ----- return if hits UI elements -------------------------------
			if (disableClick ||
				main.T.hitTestPoint(mX, mY) || 
				main.B.hitTestPoint(mX, mY) || 
				main.L.hitTestPoint(mX, mY) || 
				main.R.hitTestPoint(mX, mY) || 
				sliderBar.hitTestPoint(mX, mY))
				return;
				
			main.graphics.clear();
			mouseMoveFn = null;
			if (mouseUpFn!=null) mouseUpFn();
			var page:Page = LHS.selected;
			
			var prevTarg:Image = target;
			target = null;		// reset target
			
			// ----- find all images under cursor
			var curMousePt:Point = new Point(canvas.mouseX, canvas.mouseY);
			if (prevMousePt != null)
			{
				var AllImgs:Vector.<Image> = new Vector.<Image>();
				var selPoly:Vector.<Point> = 
				Vector.<Point>([prevMousePt,
								new Point(curMousePt.x,prevMousePt.y),
								curMousePt,
								new Point(prevMousePt.x,curMousePt.y)]);
				for (var i:int=page.Pics.length-1; i>-1; i--)
					if (polysIntersect(selPoly,page.Pics[i].Corners))
						AllImgs.unshift(page.Pics[i]);
				
				if (AllImgs.length > 1)
				{	// if selected multiple images
					if (prevMousePt.subtract(curMousePt).length > 1)
					{
						var gImg:GroupImage = new GroupImage(AllImgs);
						target = gImg;
					}
					else
						target = AllImgs.pop();
				}
				else if (AllImgs.length == 1)
					target = AllImgs[0];
			}
			
			trace("target="+target);
			
			// ----- chk if arrow or color square clicked ---------------------
			if (getTimer() - mouseDownT < 250)
			{
				trace("short click!");
				// ----- find arrow being clicked ---------------------------------
				arrow = null;
				for (var i:int=page.Arrows.length-1; i>-1; i--)
					if (page.Arrows[i].canvas.hitTestPoint(mX, mY,true))
					{
						arrow = page.Arrows[i];
						target = arrow.pic;
						if (prevTarg==target) editArrow(page.Arrows[i]);
						trace("target is arrow pic :" + target);
					}
				if (RHS!=null)
				{
					if (arrow == null) 	RHS.showNormal();
					else				RHS.loadProducts();
				}
				
				// ----- show color selector if targ is color square --------------
				if (target!=null && target.url!=null && target.url.charAt(0) == "#" && page.Pics.indexOf(target)!=-1 && prevTarg == target)
					editColorSquare(target);
			}
			
			// ----- check and add undo
			if (!LHS.canvas.hitTestPoint(stage.mouseX,stage.mouseY) && 
				(RHS==null || !RHS.canvas.hitTestPoint(stage.mouseX,stage.mouseY)) &&
				!topBar.hitTestPoint(stage.mouseX,stage.mouseY))
			{
				var s:String = getCurState();
				if (undoStk[undoStk.length-1]!=s) 
				{
					trace("push curState="+s);
					undoStk.push(s);
					updatePageImage();
				}
			}
			
			prevMousePt = null;
			updateCanvas();
			
			getProductItemsData();
		}//endfunction
		
		//=============================================================================
		// refresh this 'canvas', draws LHS.selected 
		//=============================================================================
		private function updateCanvas():void
		{
			trace("updateCanvas");
			var page:Page = LHS.selected;
			
			// ----- updates page background ------------------------
			var pW:int = paper.width/paper.scaleX;
			var pH:int = paper.height/paper.scaleY;
			paper.graphics.clear();
			paper.graphics.beginFill(0xFFFFFF, 1);
			paper.graphics.drawRect(-pW/2, -pH/2, pW, pH);
			paper.graphics.endFill();
			if (page.bg != null)
			{
				var pSc:Number = Math.min(pW / page.bg.width, pH / page.bg.height);
				paper.graphics.beginBitmapFill(page.bg, new Matrix(pSc, 0, 0, pSc, -(page.bg.width * pSc)/2, -(page.bg.height * pSc)/2));
				paper.graphics.drawRect(-page.bg.width*pSc/2, -page.bg.height*pSc/2, page.bg.width*pSc, page.bg.height*pSc);
				paper.graphics.endFill();
			}
			
			// ----- update canvas pictures -------------------------
			canvas.graphics.clear();
			for (var i:int=0; i<page.Pics.length; i++)
			{
				var pic:Image = page.Pics[i];
				pic.drawOn(canvas);
			}
			
			// ----- update canvas arrows ---------------------------
			var toAddA:Array = [];
			for (i = page.Arrows.length - 1; i > -1; i--)
			{
				toAddA.push(page.Arrows[i].canvas);
			}
			for (i = arrowsLayer.numChildren - 1; i > -1; i--)
				if (toAddA.indexOf(arrowsLayer.getChildAt(i)) == -1)
					arrowsLayer.removeChildAt(i);
			for (i = toAddA.length - 1; i > -1; i--)
				arrowsLayer.addChild(toAddA[i]);
			
			// ----- update canvas texts ----------------------------
			for (i=textLayer.numChildren-1; i>-1; i--)
				if (textLayer.getChildAt(i) is TextField && 
					page.Txts.indexOf((TextField)(textLayer.getChildAt(i)))==-1)
					textLayer.removeChildAt(i);
			for (i=0; i<page.Txts.length; i++)
				textLayer.addChild(page.Txts[i]);
			
			// ----- draw on thumbnail of page ----------------------
			drawCanvasThumb((Page)(LHS.selected).thumb.bitmapData);
			
			// ----- setup image resizing scaling shifting buttons --
			if (target!=null)
			{
				if (arrow != null) arrow.update();	// update pic within arrow
				canvas.addChild(picResizeUI);
				var cpt:Point = target.getCenter();
				setChildPosn(picResizeUI,0,cpt);
				picResizeUI.graphics.clear();
				picResizeUI.graphics.lineStyle(0, 0x3399AA);
				var cn:int = target.Corners.length;
				picResizeUI.graphics.moveTo(target.Corners[cn-1].x, target.Corners[cn-1].y);
				for (i=0; i < target.Corners.length; i++)
				{
					setChildPosn(picResizeUI,i,new Point((target.Corners[i].x+target.Corners[(i+1)%cn].x)/2,(target.Corners[i].y+target.Corners[(i+1)%cn].y)/2));
					setChildPosn(picResizeUI,i+4,target.Corners[i]);
					picResizeUI.graphics.lineTo(target.Corners[i].x, target.Corners[i].y);
				}
			}
			else
			{
				if (picResizeUI.parent!=null)
					picResizeUI.parent.removeChild(picResizeUI);
			}
		}//endfunction
		
		//=============================================================================
		// draws the capture of the current selected page
		//=============================================================================
		private function updatePageImage():void
		{
			// ----- draw screenshot
			if (LHS.selected.image == null)
				LHS.selected.image = new BitmapData(paper.width, paper.height, false, 0xFFFFFF);
			else if (	LHS.selected.image.width != paper.width || 
						LHS.selected.image.height != paper.height)
			{
				LHS.selected.image.dispose();
				LHS.selected.image = new BitmapData(paper.width, paper.height, false, 0xFFFFFF);
			}
			drawCanvasThumb(LHS.selected.image);
			LHS.selected.imageUploaded = false;
		}//endfunction
		
		//=============================================================================
		// returns combi image items data
		//=============================================================================
		public function getProductItemsData():Array
		{
			var A:Array = [];
			// ----- TEST GET ALL PIC DATA
			for (var i:int = 0; i < LHS.Pages.length; i++ )
			{
				var Pics:Vector.<Image> = LHS.Pages[i].Pics;
				for (var j:int = 0; j < Pics.length; j++)
					if (Pics[j].data != null)
					{
						//trace(prnObject(Pics[j].data));
						var D:Object = Pics[j].data;
						for (var k:* in D)
						{
							var value:String = null;
							if (D[k].attribute is String)
							{
								trace("WEIRD!!!! " + D[k].attribute);
								value = D[k].attribute;
							}
							else
								value = JSON.stringify(D[k].attribute);
							if (value != null && A.indexOf(value) == -1)	
								A.push(value);
						}
					}
			}
			return A;
		}//endfunction
		
		//=============================================================================
		// 
		//=============================================================================
		private function keyDownHandler(ev:KeyboardEvent):void
		{
			if (ev.keyCode==16)	keyShift = true;
		}//endfunction
		
		//=============================================================================
		// 
		//=============================================================================
		private function keyUpHandler(ev:KeyboardEvent):void
		{
			if (ev.keyCode==16)	keyShift = false;
		}//endfunction
		
		//=============================================================================
		// restart blank
		//=============================================================================
		public function clearAll():void
		{
			LHS.canvas.parent.removeChild(LHS.canvas);
			LHS = new LHSMenu();
			properties = LHS.projProperties;
			addChild(LHS.canvas);
			prevW = 0;
			prevH = 0;
			chkAndResize();	// force refresh
		}//endfunction
		
		//=============================================================================
		// converts current state into string data 
		//=============================================================================
		public function getCurState():String
		{
			function replacer(k:*,v:*):*
			{
				var o:Object = null;
				if (v is LHSMenu)
				{
					o = new Object();
					o.Pages = (LHSMenu)(v).Pages;
					o.Spaces = (LHSMenu)(v).Spaces;
					o.properties = (LHSMenu)(v).projProperties;
					return o;
				}
				else if (v is Space)
				{
					o = new Object();
					o.spaceId = LHS.Spaces.indexOf(v);
					o.title = (Space)(v).title;
					o.matchId = (Space)(v).getMatchId();
					return o;
				}
				else if (v is Page)			//
				{
					o = new Object();
					o.Pics = (Page)(v).Pics;
					o.Txts = (Page)(v).Txts;
					o.Arrows = (Page)(v).Arrows;
					o.title = (Page)(v).title;
					o.spaceId = LHS.Spaces.indexOf(LHS.parentSpace(v));
					o.pageId = (Page)(v).pageId;
					o.bgUrl = (Page)(v).bgUrl;
					o.imageUploaded = (Page)(v).imageUploaded;
					return o;
				}
				else if (v is CropImage)
				{
					o = new Object();
					o.image = (CropImage)(v).image;
					o.Corners = (CropImage)(v).Corners;
					o.uvCrop = (CropImage)(v).uvCrop;
					return o;
				}
				else if (v is GroupImage)
				{
					return (GroupImage)(v).Images;
				}
				else if (v is Image)
				{
					o = new Object();
					o.id = v.id;	
					o.pic = v.url;	// the image url
					o.Corners = v.Corners;
					if (v.data!=null) o.data = v.data;
					return o;
				}
				else if (v is Point)
				{
					o = new Object();
					o.x = v.x;
					o.y = v.y;
					return o;
				}
				else if (v is TextField)
				{
					o = new Object();
					o.x = v.x;
					o.y = v.y;
					o.text = v.text;
					o.size = (TextField)(v).defaultTextFormat.size;
					o.color = (TextField)(v).defaultTextFormat.color;
					return o;
				}
				else if (v is Arrow)
				{
					o = new Object();
					o.ox = (Arrow)(v).tail.x;
					o.oy = (Arrow)(v).tail.y;
					o.image = (Arrow)(v).pic;
					o.color = (Arrow)(v).color;
					return o;
				}
				return v;
			}
			return JSON.stringify(LHS,replacer);
		}//endfunction
		
		//=============================================================================
		// parses JSON data and restore 
		//=============================================================================
		private var enableRestoreFromData:Boolean = true;
		public function restoreFromData(s:String):void
		{
			if (!enableRestoreFromData)	return;
			enableRestoreFromData = false;
			trace("restoreFrom "+s);
			
			var i:int=0;
			var o:Object = JSON.parse(s);
			
			var picsToLoad:Array = [];
			// ------ preload all pics before restore proper
			function readNestedPics(P:Array):void
			{
				for (var j:int = 0; j < P.length; j++)
					if (P[j] is Array)
						readNestedPics(P[j]);
					else if (P[j].image != null)		// the crop image data
					{
						if (P[j].image is GroupImage)
							readNestedPics(P[j].image);
						else
							picsToLoad.push(P[j].image);
					}
					else
						picsToLoad.push(P[j]);
			}
			for (i = 0; i < o.Pages.length; i++)
			{
				readNestedPics(o.Pages[i].Pics);
				for (var j:int=0; j<o.Pages[i].Arrows.length; j++)
					picsToLoad.push(o.Pages[i].Arrows[j].image);
			}
			
			var pidx:int=0;
			function loadNextPic():void
			{
				if (pidx>=picsToLoad.length)
					restoreProper();
				else
				{
					if (picsToLoad[pidx] is Array)
					{
						trace("restoreFromData loadNextPic ERROR! picsToLoad[" + pidx + "] is array!!");
					}
					else if (picsToLoad[pidx].pic == null)
					{
						trace("restoreFromData loadNextPic ERROR! picsToLoad[" + pidx + "].pic=" + picsToLoad[pidx].pic);
						pidx++;
						loadNextPic();
					}
					else if ((String)(picsToLoad[pidx].pic).charAt(0) == "#")
					{	// is a color square , initialize color 
						picsToLoad[pidx].bitmapData = new BitmapData(100, 100, false, parseInt((String)(picsToLoad[pidx].pic).split("#")[1],16));
						pidx++;
						loadNextPic();
					}
					else
					MenuUtils.loadAsset(baseUrl+picsToLoad[pidx].pic,function(bmp:Bitmap):void
					{	// is an image, initialize image
						if (bmp == null)
							trace("loadAsset :"+baseUrl+picsToLoad[pidx].pic+" = "+bmp);
						else
							picsToLoad[pidx++].bitmapData = bmp.bitmapData;
						loadNextPic();
					});
				}
			}//endfunction
			loadNextPic();
			
			// ------------------------------------------------------
			function parseImages(A:Array):GroupImage
			{
				var I:Vector.<Image> = new Vector.<Image>();
				for (var j:int=0; j<A.length; j++)
				{
					var po:Object = A[j];
					var image:Image = null;
					if (po is Array)							// ----- is group image
						image = parseImages(po);		
					else if (po.uvCrop!=null && po.image!=null)	// ----- is crop image
					{
						image = new CropImage(parseImages([po.image]).Images[0]);
						(CropImage)(image).uvCrop = new Rectangle(po.uvCrop.x,po.uvCrop.y,po.uvCrop.width,po.uvCrop.height);
						image.Corners[0] = new Point(po.Corners[0].x,po.Corners[0].y);
						image.Corners[1] = new Point(po.Corners[1].x,po.Corners[1].y);
						image.Corners[2] = new Point(po.Corners[2].x,po.Corners[2].y);
						image.Corners[3] = new Point(po.Corners[3].x,po.Corners[3].y);
					}
					else										// ----- is normal image
					{
						image = new Image(po.id,po.pic);
						image.setBmd(po.bitmapData);
						image.Corners[0] = new Point(po.Corners[0].x,po.Corners[0].y);
						image.Corners[1] = new Point(po.Corners[1].x,po.Corners[1].y);
						image.Corners[2] = new Point(po.Corners[2].x,po.Corners[2].y);
						image.Corners[3] = new Point(po.Corners[3].x,po.Corners[3].y);
						if (po.data != null) image.data = po.data;
					}
					I.push(image);
				}
				return new GroupImage(I);
			}//endfunction
			
			//-------------------------------------------------------
			function loadPageBackground(pg:Page):void
			{
				if (pg.bgUrl!=null)
				MenuUtils.loadAsset(baseUrl+pg.bgUrl,function(bmp:Bitmap):void
				{
					pg.bg = bmp.bitmapData;
				});
			}//endfunction
			
			//-------------------------------------------------------
			function restoreProper() : void
			{	
				var Spcs:Vector.<Space> = new Vector.<Space>();
				for (i=0; i<o.Spaces.length; i++)	Spcs.push(null);
				for (i=0; i<o.Spaces.length; i++)
				{
					var spc:Space = new Space();
					spc.title = o.Spaces[i].title;
					spc.Pages.pop();					// remove the default blank page
					Spcs[o.Spaces[i].spaceId] = spc;	// put space at spaceid
				}//endfor	
					
				for (i=0; i<o.Pages.length; i++)
				{
					var pg:Page = new Page(o.Pages[i].title);
					pg.pageId = o.Pages[i].pageId;
					if (Page.uniqueCnt < pg.pageId + 1)	Page.uniqueCnt = pg.pageId + 1;	// ensure correct unique countid
					pg.imageUploaded = o.Pages[i].imageUploaded;
					Spcs[o.Pages[i].spaceId].Pages.push(pg);	// put page in space at id
					pg.bgUrl = o.Pages[i].bgUrl;
					if (pg.bgUrl!=null)	loadPageBackground(pg);
					
					// ----- parse pics
					pg.Pics = parseImages(o.Pages[i].Pics).Images;
					
					// ----- parse text
					for (j=0; j<o.Pages[i].Txts.length; j++)
					{
						var to:Object = o.Pages[i].Txts[j];
						var tf:TextField = new TextField();
						tf.wordWrap = false;
						tf.autoSize = "left";
						var tff:TextFormat = tf.defaultTextFormat;
						tff.size = to.size;
						tff.color = to.color;
						tf.defaultTextFormat = tff;
						tf.text = to.text;
						tf.x = to.x;
						tf.y = to.y;
						pg.Txts.push(tf);
					}
					
					// ----- parse image
					for (j=0; j<o.Pages[i].Arrows.length; j++)
					{
						var ao:Object = o.Pages[i].Arrows[j];
						var arr:Arrow = new Arrow();
						arr.tail.x = ao.ox;
						arr.tail.y = ao.oy;
						arr.pic = parseImages([ao.image]).Images[0];
						pg.Arrows.push(arr);
						arr.update();
					}
				}//endfor
			
				LHS.updateSpaces(Spcs);	// override Spaces and Pages data
				
				// ----- override properties 
				properties = new ProjProperties();
				properties.address = o.properties.address;
				properties.area = o.properties.area;
				properties.details = o.properties.details;
				properties.form = o.properties.form;
				properties.lastModify = o.properties.lastModify;
				properties.name = o.properties.name;
				properties.project = o.properties.project;
				properties.saveId = o.properties.saveId;
				properties.serial = o.properties.serial;
				properties.sheng = o.properties.sheng;
				properties.shi = o.properties.shi;
				properties.qu = o.properties.qu;
				properties.style = o.properties.style;
				properties.type = o.properties.type;
				LHS.projProperties = properties;
				
				target = null;
			
				// ----- refresh LHS thumbnails
				for (i=0; i<LHS.Pages.length; i++)
				{
					LHS.selected = LHS.Pages[i];
					updateCanvas();		// trigger redraw thumbnail
				}
				trace("enableRestoreFromData");
				enableRestoreFromData = true;
			}//endfunction
		}//endfunction
		
		//=============================================================================
		// write data to SharedObject LOCALLY
		//=============================================================================
		public function saveToSharedObject():void
		{
			var bmd:BitmapData = generateSaveThumb();
			var jpgEnc:JPGEncoder = new JPGEncoder(80);
			var ba:ByteArray = jpgEnc.encode(bmd);
			var M:Array = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
			var dat:Date = new Date();
			
			var so:SharedObject = SharedObject.getLocal("ImageTool");
			var saveDat:Array = so.data.savedData;	// name,tmbByteArr,datastring
			if (saveDat==null) saveDat = [];
			for (var i:int=saveDat.length-1; i>-1; i-=3)
			{
				if (JSON.parse(saveDat[i]).saveId==saveId)
					saveDat.splice(i-2,3);
			}
			var saveName:String = 	properties.name + "\n" + 
									properties.sheng.split("|")[1] +" " + properties.shi.split("|")[1] + " " + properties.qu.split("|")[1]+"\n"+
									dat.date + " " + M[dat.month] + " " + dat.fullYear;
			saveDat.unshift(saveName , ba , getCurState());
			if (saveDat.length>20*3) saveDat = saveDat.slice(0,20*3);
			so.data.savedData = saveDat;
			so.flush();
			
		}//endfunction
		
		//=============================================================================
		// write data to server, and get saveId from server return
		//=============================================================================
		public function sendPageImagesToServer(callBack:Function = null):void
		{
			trace("sendPageImagesToServer");
			var P:Vector.<Page> = LHS.Pages.slice();
			var pidx:int = 0;
			var jpgEnc:JPGEncoder = new JPGEncoder(90);
			
			function uploadNextPic():void
			{
				if (P[pidx].imageUploaded)
				{
					pidx++;
					if (pidx < P.length)	uploadNextPic();
					else if (callBack!=null)	callBack();
				}
				else
				{
					var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme_page_pic&m=add&saveid="+saveId+"&pageid="+P[pidx].pageId+"&token="+userToken);
					req.contentType = 'application/octet-stream';
					req.method = URLRequestMethod.POST;
					if (P[pidx].image == null)	P[pidx].image = new BitmapData(paper.width, paper.height, false, 0xFFFFFF);
					req.data = jpgEnc.encode(P[pidx].image);
					trace("pidx="+pidx+"\nupload request : "+req.url+"\nreq.data : "+req.data.length)
					var ldr:URLLoader = new URLLoader();
					function onComplete(ev:Event):void
					{
						trace("page image uploaded response =" + ldr.data);
						P[pidx].imageUploaded = true;
						pidx++;
						if (pidx < P.length)	uploadNextPic();
						else if (callBack!=null)	callBack();
					}//endfunction
					ldr.addEventListener(IOErrorEvent.IO_ERROR, onComplete);
					ldr.addEventListener(Event.COMPLETE, onComplete);  
					ldr.load(req);
				}
			}
			
			if (P.length > 0)	uploadNextPic();
			else if (callBack != null)	callBack();
		}//endfunction
		
		//=============================================================================
		// write data to server, and get saveId from server return
		//=============================================================================
		public function saveToServer(nam:String="incognito",callBack:Function=null):void
		{
			var dat:Date = new Date();
			var M:Array = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
			
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = null;
			if (saveId=="")
				req = new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=add&token="+userToken);
			else
				req = new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=edit&token="+userToken+"&id="+saveId);
			trace("saveToServer : "+req);
			req.method = "post";  
			var vars:URLVariables = new URLVariables();  
			vars.token = userToken;  
			vars.name = properties.name;// +"\n" + properties.sheng.split("|")[1] +" " + properties.shi.split("|")[1] + " " + properties.qu.split("|")[1] +"\n" + dat.date + " " + M[dat.month] + " " + dat.fullYear;
			vars.scale= "$:3";
			vars.classids= "1,2,3";
			//prn(getCurState());
			vars.json = getCurState();
			req.data = vars;
		
			function onComplete(ev:Event):void
			{
				var o:Object = JSON.parse(ldr.data);
				if (o.data!=null && o.data.id!=null) saveId = o.data.id;
				sendPageImagesToServer(callBack);
			}//endfunction
			ldr.addEventListener(Event.COMPLETE, onComplete);
			
			ldr.load(req);
		}//endfunction
		
		//=============================================================================
		// sets current selected image ss background of 
		//=============================================================================
		public function setTargetAsBg(mode:int=0):void
		{
			if (target == null) return;
			var page:Page = LHS.selected;
			if (page.Pics.indexOf(target) != -1)
				page.Pics.splice(page.Pics.indexOf(target), 1);
				
			if (mode==0)
			{
				page.bg = target.bmd;						// bg bitmapData
				page.bgUrl = target.url;					// url of bg bitmap
			}
			if (mode==1)
			{
				var space:Space = LHS.parentSpace(page);
				for (var i:int=space.Pages.length-1; i>-1; i--)
				{
					space.Pages[i].bg = target.bmd;			// bg bitmap
					space.Pages[i].bgUrl = target.url;		// url of bg bitmap
					LHS.selected = space.Pages[i];
					updateCanvas();							// just to force refresh thumbnails
				}
				
			}
			if (mode==2)
			{
				for (var j:int=LHS.Spaces.length-1; j>-1; j--)
				{
					space = LHS.Spaces[j];
					for (i=space.Pages.length-1; i>-1; i--)
					{
						space.Pages[i].bg = target.bmd;		// bg bitmap
						space.Pages[i].bgUrl = target.url;	// url of bg bitmap		
						LHS.selected = space.Pages[i];
						updateCanvas();						// just to force refresh thumbnails
					}
				}
			}
			LHS.selected = page;
			
			// ----- save this state to undo stk
			var s:String = getCurState();
			if (undoStk[undoStk.length-1]!=s) 
			{
				trace("setTargetAsBg push curState="+s);
				undoStk.push(s);
				updatePageImage();
			}
		}//endfunction
		
		//=============================================================================
		// adds image onto drawing canvas
		//=============================================================================
		private function addImage(img:Image):void 
		{
			if (img.bmd==null) return;	// failsafe
			
			if (arrow!=null)
			{
				arrow.replacePic(img);
			}
			else
			{
				LHS.selected.Pics.push(img);	// add image to Page
			}
			updateCanvas();
		}//endfunction
		
		//=============================================================================
		// adds textField onto drawing canvas
		//=============================================================================
		public function addText():TextField
		{
			var tf:TextField = utils.createInputText(function():void 
			{
			},"TEXT");
			canvas.addChild(tf);
			
			mouseMoveFn = function():void
			{
				tf.x = canvas.mouseX;
				tf.y = canvas.mouseY;
			} 
			
			mouseUpFn = function():void
			{
				mouseUpFn = null;
			}
			
			LHS.selected.Txts.push(tf);
			return tf;
		}//endfunction
		
		//=============================================================================
		// edits the selected textfield on drawing canvas
		//=============================================================================
		private var propMenu:Sprite = null;
		public function editText(tf:TextField,callBack:Function=null):void
		{
			tf.border = true;
			tf.background = true;
			tf.type = "input";
			tf.addEventListener(FocusEvent.FOCUS_OUT,endHandler);
			tf.addEventListener(Event.REMOVED_FROM_STAGE,endHandler);
			
			// ------------------------------------------------------
			function createTextPropertiesMenu():Sprite
			{
				var s:Sprite = 
				utils.createChoices("字体",
									Vector.<String>(["字体大小 "+tf.defaultTextFormat.size, 
													"字体颜色 " + tf.defaultTextFormat.color.toString(16),
													"删除", 
													"确认"]),
									Vector.<Function>([	function():void 			// change font size fn
														{
															var tff:TextFormat = tf.defaultTextFormat;
															var btn0:Sprite = s.getChildAt(1) as Sprite;
															var inTf:TextField = utils.createInputText(function(txt:String):void 
															{
																(TextField)(btn0.getChildAt(0)).text = "字体大小 " + tff.size;
																if (isNaN(parseInt(txt))) return;
																tff.size = parseInt(txt);
																tf.defaultTextFormat = tff;
																tf.setTextFormat(tff);
																(TextField)(btn0.getChildAt(0)).text = "字体大小 " + tff.size;
																if (inTf.parent!=null) inTf.parent.removeChild(inTf);
															}, tf.defaultTextFormat.size + "", btn0.width);
															(TextField)(btn0.getChildAt(0)).text = "";
															inTf.x = btn0.x; 
															inTf.y = btn0.y;
															s.addChild(inTf);
														},
														function():void 			// change text color
														{
															showColorMenu(function(color:uint):void 
																		{
																			var tff:TextFormat = tf.defaultTextFormat;
																			tff.color = color;
																			tf.defaultTextFormat = tff;
																			tf.setTextFormat(tff);
																			showLabelProperties();
																		});
														},
														function():void 			// remove text 
														{
															LHS.selected.Txts.splice(LHS.selected.Txts.indexOf(tf),1);
															if (tf.parent != null) tf.parent.removeChild(tf);
															endEdit();
														},
														function():void 			// done editing text 
														{
															endEdit();
															
														}	]));
				s.filters = [new DropShadowFilter(3,45,0x000000)];
				return s;
			}
			
			// ------------------------------------------------------
			function showLabelProperties():void 
			{
				trace("showLabelProperties");
				replaceMenu(createTextPropertiesMenu());
			}//endfunction
			
			// ------------------------------------------------------
			function showColorMenu(callBack:Function):void
			{
				replaceMenu(createColorMenu(callBack));
			}//endfunction
			
			// ------------------------------------------------------
			function replaceMenu(men:Sprite):void
			{
				if (propMenu!=null && propMenu.parent!=null)	
					propMenu.parent.removeChild(propMenu);
				
				propMenu = men;	
				addChild(propMenu);
				if (tf.x+tf.width/2<0)
					propMenu.x = canvas.x+tf.x+tf.width+10;
				else
					propMenu.x = canvas.x+tf.x-propMenu.width-10;
					
				if (tf.y+tf.height/2<0)
					propMenu.y = canvas.y+tf.y+tf.height+10;
				else
					propMenu.y = canvas.y+tf.y-propMenu.height-10;
				
				trace("propMenu posn=(" + propMenu.x + "," + propMenu.y + ")");
			}//endfunction
			
			showLabelProperties();
			
			function endHandler(ev:Event):void
			{
				trace("endHandler");
				if (propMenu.hitTestPoint(stage.mouseX,stage.mouseY)) return;
				endEdit();
			}//endfunction
			
			function endEdit():void
			{
				tf.removeEventListener(KeyboardEvent.KEY_DOWN,endHandler);
				tf.removeEventListener(Event.REMOVED_FROM_STAGE,endHandler);
				tf.border = false;
				tf.background = false;
				tf.type = "dynamic";
				if (propMenu!=null && propMenu.parent!=null)
				propMenu.parent.removeChild(propMenu);
				if (callBack!=null) callBack();
			}
			
			mouseMoveFn = function():void	// set global mouse move function
			{
				tf.x = canvas.mouseX;
				tf.y = canvas.mouseY;
			} 
			
		}//endfunction
		
		//=============================================================================
		// pops up color selector to set color for given color square
		//=============================================================================
		public function editColorSquare(target:Image):void
		{
			var colorMen:Sprite = createColorMenu(function(c:uint):void 
			{
				target.url = "#" + c.toString(16);
				target.id = target.url;
				trace("target.id="+target.id);
				target.bmd.fillRect(new Rectangle(0, 0, target.bmd.width, target.bmd.height), c);
			});
			var cpt:Point = target.getCenter();
			var minPt:Point = cpt.clone();
			var maxPt:Point = cpt.clone();
			for (var i:int = 0; i < target.Corners.length; i++)
			{
				if (minPt.x > target.Corners[i].x) minPt.x = target.Corners[i].x;
				if (maxPt.x < target.Corners[i].x) maxPt.x = target.Corners[i].x;
				if (minPt.y > target.Corners[i].y) minPt.y = target.Corners[i].y;
				if (maxPt.y < target.Corners[i].y) maxPt.y = target.Corners[i].y;
			}
			if (cpt.x>0)	colorMen.x = canvas.x + minPt.x*canvas.scaleX-colorMen.width;
			else			colorMen.x = canvas.x + maxPt.x*canvas.scaleX;
			if (cpt.y>0)	colorMen.y = canvas.y + minPt.y*canvas.scaleY-colorMen.height;
			else			colorMen.y = canvas.y + maxPt.y*canvas.scaleY;
			function closeHandler(ev:Event):void
			{
				if (colorMen.hitTestPoint(stage.mouseX, stage.mouseY)) return;
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, closeHandler);
				if (colorMen.parent != null) colorMen.parent.removeChild(colorMen);
			}//endfunction
			stage.addEventListener(MouseEvent.MOUSE_DOWN, closeHandler);
			
			addChild(colorMen);
		}//endfunction
		
		//=============================================================================
		// edits the selected textfield on drawing canvas
		//=============================================================================
		public function editArrow(arr:Arrow,callBack:Function=null):void
		{
			function createTextPropertiesMenu():Sprite
			{
				var s:Sprite = 
				utils.createChoices("箭头",
									Vector.<String>(["颜色 " +  arr.color.toString(16),
													"删除", 
													"确认"]),
									Vector.<Function>([	function():void 			// change text color
														{
															showColorMenu(function(color:uint):void 
																		{
																			arr.color = color;
																			arr.update();
																			showArrowProperties();
																		});
														},
														function():void 			// remove arrow 
														{
															LHS.selected.Arrows.splice(LHS.selected.Arrows.indexOf(arr),1);
															if (arr.canvas.parent != null) arr.canvas.parent.removeChild(arr.canvas);
															endEdit();
														},
														function():void 			// done editing text 
														{
															endEdit();
															
														}	]));
				s.filters = [new DropShadowFilter(3,45,0x000000)];
				return s;
			}
				
			// ------------------------------------------------------
			function showArrowProperties():void 
			{
				trace("showArrowProperties");
				replaceMenu(createTextPropertiesMenu());
			}//endfunction
			
			// ------------------------------------------------------
			function showColorMenu(callBack:Function):void
			{
				replaceMenu(createColorMenu(callBack));
			}//endfunction
			
			// ------------------------------------------------------
			function replaceMenu(men:Sprite):void
			{
				if (propMenu!=null && propMenu.parent!=null)	
					propMenu.parent.removeChild(propMenu);
				
				propMenu = men;	
				addChild(propMenu);
				if (arr.canvas.x+arr.canvas.width/2<0)
					propMenu.x = canvas.x+arr.canvas.x+arr.canvas.width+10;
				else
					propMenu.x = canvas.x+arr.canvas.x-propMenu.width-10;
					
				if (arr.canvas.y+arr.canvas.height/2<0)
					propMenu.y = canvas.y+arr.canvas.y+arr.canvas.height+10;
				else
					propMenu.y = canvas.y+arr.canvas.y-propMenu.height-10;
			}//endfunction
			
			showArrowProperties();
			
			function endEdit():void
			{
				if (propMenu!=null && propMenu.parent!=null)
				propMenu.parent.removeChild(propMenu);
				if (callBack!=null) callBack();
			}
			
			function endTrigger(ev:Event):void
			{
				if (arr.canvas.hitTestPoint(stage.mouseX, stage.mouseY, true) || 
					propMenu.hitTestPoint(stage.mouseX, stage.mouseY) )	return;
				stage.removeEventListener(MouseEvent.MOUSE_UP,endTrigger);
				endEdit();
			}
			stage.addEventListener(MouseEvent.MOUSE_UP,endTrigger);
			
		}//endfunction
	
		//=============================================================================
		// shows the color picker menu
		//=============================================================================
		public function createColorMenu(callBack:Function):Sprite
		{
			var s:ColorSelect = new ColorSelect();
			var c:uint = 0x000000;
			
			function clickHandler(ev:Event):void
			{
				if (s.btn.hitTestPoint(stage.mouseX,stage.mouseY))
				{
					trace("?");
					if (callBack!=null) callBack(c);
					if (s.parent!=null) s.parent.removeChild(s);
					return;
				}
				var bmd:BitmapData = new BitmapData(1,1,false,0x00000000);
				bmd.draw(s,new Matrix(1,0,0,1,-s.mouseX,-s.mouseY));
				c = bmd.getPixel(0,0);
				var wh:Point = new Point(s.colorBox.width,s.colorBox.height);
				while (s.colorBox.numChildren>0)	s.colorBox.removeChildAt(0);
				s.colorBox.graphics.clear();
				s.colorBox.graphics.beginFill(c);
				s.colorBox.graphics.drawRoundRect(0,0,wh.x,wh.y,3,3);
				s.colorBox.graphics.endFill();
				var tf:TextField = utils.createText(c.toString(16),-1,15,0x1000000-c);
				tf.selectable = true;
				tf.x = (s.colorBox.width-tf.width)/2;
				tf.y = (s.colorBox.height-tf.height)/2;
				s.colorBox.addChild(tf);
				trace("c="+c);
			}//endfunction
			
			function cleanUpHandler(ev:Event):void
			{
				s.removeEventListener(Event.REMOVED_FROM_STAGE,cleanUpHandler);
				s.removeEventListener(MouseEvent.CLICK, clickHandler);
			}//endfunction
			
			s.addEventListener(Event.REMOVED_FROM_STAGE,cleanUpHandler);
			s.addEventListener(MouseEvent.CLICK, clickHandler);
			s.filters = [new DropShadowFilter(1,45,0x000000,1,4,4,1)];
			return s;
		}//endfunction
		
		//=============================================================================
		// generates thumb for the save load menu
		//=============================================================================
		public function generateSaveThumb():BitmapData
		{
			var n:int = LHS.Pages.length;
			if (n>5) n=5;
			var bmd:BitmapData = new BitmapData(100,100,false,0xFFFFFF);
			for (var i:int=0; i<LHS.Pages.length; i++)
			{
				updateCanvas();
				drawCanvasThumb(bmd);
			}
			return bmd;	
		}//endfunction
		
		//=============================================================================
		// generate all pages of the 
		//=============================================================================
		public function generatePDF(flags:String=null):void
		{
			var papersize:Size = new Size(	[paper.width,paper.height],
											"Paper Size",
											[paper.width/25.4,paper.height/25.4],
											[paper.width,paper.height]);
			var printPDF:PDF = new PDF( Orientation.PORTRAIT, 
										"Mm", 
										papersize);
			printPDF.setMargins(0,0);
			for (var i:int=0; i<LHS.Pages.length; i++)
			{
				if (flags == null || flags.charAt(i) != "0")
				{
					LHS.selected = LHS.Pages[i];
					updateCanvas();
					
					printPDF.addPage(new (org.alivepdf.pages.Page)(Orientation.PORTRAIT,"Mm",papersize));
					var bmp:Bitmap = new Bitmap(new BitmapData(paper.width,paper.height,false,0xFFFFFFFF));
					drawCanvasThumb(bmp.bitmapData);
					//printPDF.gotoPage(i+1);
					printPDF.addImage(bmp);
				}
			}
			var ba:ByteArray = printPDF.save( Method.LOCAL);
			var fr:FileReference = new FileReference();
			fr.save(ba,"export.pdf");
		}//endfunction
		
		//=============================================================================
		// 
		//=============================================================================
		private function drawCanvasThumb(bmd:BitmapData):void
		{
			// ----- draw on thumbnail of page ----------------------
			picResizeUI.visible = false;
			//bmd.fillRect(new Rectangle(0,0,bmd.width,bmd.height),0xFFCC00CC);
			var mat:Matrix = new Matrix(bmd.width/paper.width*paper.scaleX,0,0,bmd.height/paper.height*paper.scaleY,bmd.width/2,bmd.height/2);
			bmd.draw(paper,mat);
			bmd.draw(canvas,mat);
			picResizeUI.visible = true;
		}//endfunction
		
		//=============================================================================
		// creates a vertical slider bar of wxh dimensions  
		//=============================================================================
		private function createHSlider(callBack:Function,w:int=150):Sprite
		{
			var h:int = 5;
			
			// ----- main sprite
			var s:Sprite = new Sprite();
			s.graphics.beginFill(0xCCCCCC,1);
			s.graphics.drawRect(0,0,w,h);
			s.graphics.endFill();
		
			// ----- slider knob
			var slider:Sprite = new Sprite();
			slider.graphics.beginFill(0xEEEEEE,1);
			slider.graphics.drawCircle(0,0,h);
			slider.graphics.endFill();
			slider.graphics.beginFill(0x333333,1);
			slider.graphics.drawCircle(0,0,h/2);
			slider.graphics.endFill();
			slider.buttonMode = true;
			slider.mouseChildren = false;
			slider.filters = [new DropShadowFilter(2)];
			slider.x = w/2;
			slider.y = h/2;
			s.addChild(slider);
			
			function updateHandler(ev:Event):void
			{
				if (callBack!=null) callBack(1-slider.x/w);
			}
			function startDragHandler(ev:Event):void
			{
				if (slider.hitTestPoint(stage.mouseX,stage.mouseY))
					slider.startDrag(false,new Rectangle(0,slider.y,w,0));
				else
					s.startDrag();
				stage.addEventListener(Event.ENTER_FRAME,updateHandler);
				stage.addEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
			}
			function stopDragHandler(ev:Event):void
			{
				s.stopDrag();
				slider.stopDrag();
				stage.removeEventListener(Event.ENTER_FRAME,updateHandler);
				stage.removeEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
			}
			s.addEventListener(MouseEvent.MOUSE_DOWN,startDragHandler);
		
			return s;
		}//endfunction
		
		//=============================================================================
		// 
		//=============================================================================
		public static function prnObject(o:Object,nest:int=0):String
		{
			var tabs:String="";
			for (var i:int=0; i<nest; i++)
				tabs+="  ";
				
			var s:String = "{";
			for(var id:String in o) 
			{
				var value:Object = o[id];
				if (value is String || value is int || value is Number || value is Boolean)
					s += "\n"+tabs+"  "+id+"="+value;
				else
					s += "\n"+tabs+"  "+id+"="+prnObject(value,nest+1);
			}
			return s+"}";
		}//endfunction
		
		//=============================================================================
		// convenience function to set child position of child at index
		//=============================================================================
		private static function setChildPosn(s:Sprite,cidx:int,pt:Point):void
		{
			var c:DisplayObject = s.getChildAt(cidx);
			c.x = pt.x;
			c.y = pt.y;
		}//endfunction
		
		//=============================================================================
		// rotates given pt around by given ang in radians
		//=============================================================================
		private static function rotatePoint(pt:Point,ang:Number):Point
		{
			return new Point(pt.x*Math.cos(ang)+pt.y*Math.sin(ang) , pt.y*Math.cos(ang)-pt.x*Math.sin(ang));
		}//endfunction
		
		//=======================================================================================
		// returns if polygons intersect
		//=======================================================================================
		private static function polysIntersect(P:Vector.<Point>,Q:Vector.<Point>):Boolean
		{
			for (var i:int=P.length-1; i>-1; i--)
				if (pointInPoly(P[i],Q)) return true;
			
			for (i=Q.length-1; i>-1; i--)
				if (pointInPoly(Q[i],P)) return true;
			
			for (i=P.length-1; i>0; i--)
				if (hitTestPoly(P[i].x,P[i].y,P[i-1].x,P[i-1].y,Q))	return true;
			if (hitTestPoly(P[0].x,P[0].y,P[P.length-1].x,P[P.length-1].y,Q))	return true;
				
			return false;
		}//endfunction
		
		//=======================================================================================
		// returns hearest intersect point to ax,ay or null
		//=======================================================================================
		public static function hitTestPoly(ax:Number,ay:Number,bx:Number,by:Number,Poly:Vector.<Point>):Point
		{
			var n:int = Poly.length;
			var r:Point = null;
			for (var i:int=n; i>0; i--)
			{
				var hit:Point = segmentsIntersectPt(Poly[i%n].x,Poly[i%n].y,Poly[i-1].x,Poly[i-1].y,ax,ay,bx,by);
				if (hit!=null)
				{
					if (r==null || 
						(hit.x-ax)*(hit.x-ax)+(hit.y-ay)*(hit.y-ay) > (r.x-ax)*(r.x-ax)+(r.y-ay)*(r.y-ay))
						r = hit;
				}
			}
			return r;
		}//endfunction
		
		//=======================================================================================
		// tests if pt is within polygon
		//=======================================================================================
		private static function pointInPoly(pt:Point,Poly:Vector.<Point>):Boolean
		{
			// ----- find external point (top left)
			var n:int = Poly.length;
			var extPt:Point = new Point(0,0);
			for (var i:int=n-1; i>-1; i--)
			{
				if (Poly[i].x<extPt.x)	extPt.x = Poly[i].x;
				if (Poly[i].y<extPt.y)	extPt.y = Poly[i].y;
			}
			extPt.x-=1;
			extPt.y-=1;
			
			var cnt:int=0;	// count number of intersects
			for (i=n-1; i>0; i--)
				if (segmentsIntersectPt(Poly[i].x,Poly[i].y,Poly[i-1].x,Poly[i-1].y,extPt.x,extPt.y,pt.x,pt.y))
					cnt++;
			if (segmentsIntersectPt(Poly[0].x,Poly[0].y,Poly[n-1].x,Poly[n-1].y,extPt.x,extPt.y,pt.x,pt.y))
				cnt++;
			
			return (cnt%2)==1;
		}//endfunction
	
		//=======================================================================================
		// find line segments intersect point of lines A=(ax,ay,bx,by) C=(cx,cy,dx,dy)
		// returns null for parrallel segs and point segments, does not detect end points
		//=======================================================================================
		private static function segmentsIntersectPt(ax:Number,ay:Number,bx:Number,by:Number,cx:Number,cy:Number,dx:Number,dy:Number) : Point
		{
			if ((ax==cx && ay==cy) || (ax==dx && ay==dy)) return null;	// false if any endpoints are shared
			if ((bx==cx && by==cy) || (bx==dx && by==dy)) return null;
				
			var avx:Number = bx-ax;
			var avy:Number = by-ay;
			var cvx:Number = dx-cx;
			var cvy:Number = dy-cy;
					
			var al:Number = Math.sqrt(avx*avx + avy*avy);	// length of seg A
			var cl:Number = Math.sqrt(cvx*cvx + cvy*cvy);	// length of seg C
			
			if (al==0 || cl==0 || avx/al==cvx/cl || avy/al==cvy/cl)		return null;
			
			var ck:Number = -1;
			if (avx/al==0)		ck = (ax-cx)/cvx*cl;
			else	ck = (cy-ay + (ax-cx)*avy/avx) / (cvx/cl*avy/avx - cvy/cl);
			
			var ak:Number = -1;
			if (cvx/cl==0)		ak = (cx-ax)/avx*al;
			else	ak = (ay-cy + (cx-ax)*cvy/cvx) / (avx/al*cvy/cvx - avy/al);
				
			if (ak<=0 || ak>=al || ck<=0 || ck>=cl)	return null;
				
			return new Point(ax + avx/al*ak,ay + avy/al*ak);
		}//endfunction
		
	}//endclass
	
}//endpackage


import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.filters.DropShadowFilter;
import flash.filters.GlowFilter;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.net.URLVariables;
import flash.text.TextField;


class Arrow
{
	public var canvas:Sprite = null;
	public var pic:Image = null;
	public var head:Sprite = null;
	public var tail:Sprite = null;
	public var color:uint = 0x334455;
	
	//=============================================================================
	// 
	//=============================================================================
	public function Arrow():void
	{
		canvas = new Sprite();
		canvas.filters = [new DropShadowFilter(1,45,0x000000)];
		
		// ----- arrowhead graphic
		head = new Sprite();
		head.buttonMode = true;
		canvas.addChild(head);
		
		// ----- arrow tail graphic
		tail = new Sprite();
		canvas.addChild(tail);
		
		// ----- 
		pic = new Image();
		pic.url = pic.id = "#" + color.toString(16);
		pic.setBmd(new BitmapData(100,100,false,color));
		pic.centerTo(0,-100);
		
		update();
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function replacePic(img:Image):void
	{
		img.Corners = pic.Corners;
		pic = img;				// override image in arrow
		update();
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function update(ev:Event=null):void
	{
		head.graphics.clear();
		head.graphics.beginFill(color);
		head.graphics.moveTo(0,0);
		head.graphics.lineTo( 8,30);
		head.graphics.lineTo(-8,30);
		head.graphics.endFill();
		
		tail.graphics.clear();
		tail.graphics.beginFill(color);
		tail.graphics.drawCircle(0,0,8);
		tail.graphics.endFill();
		
		canvas.graphics.clear();
		canvas.graphics.lineStyle(3,color,1);
		
		var ctr:Point = pic.getCenter();
		
		var hpt:Point = PPTool.hitTestPoly(tail.x, tail.y, ctr.x, ctr.y,pic.Corners);
		if (hpt == null) hpt = new Point(tail.x,tail.y);
		head.x = hpt.x;
		head.y = hpt.y;
		var v:Point = new Point(hpt.x-tail.x,hpt.y-tail.y);
		if (v.x*v.x<v.y*v.y)
		{
			canvas.graphics.moveTo(tail.x,tail.y);
			canvas.graphics.lineTo(tail.x,tail.y+v.y/2);
			canvas.graphics.lineTo(hpt.x,tail.y+v.y/2);
			if (v.y < 0)
			{
				canvas.graphics.lineTo(hpt.x,hpt.y+10);
				head.rotation = 0;	
			}
			else
			{
				canvas.graphics.lineTo(hpt.x,hpt.y-10);
				head.rotation = 180;
			}
		}
		else
		{
			canvas.graphics.moveTo(tail.x,tail.y);
			canvas.graphics.lineTo(tail.x+v.x/2,tail.y);
			canvas.graphics.lineTo(tail.x+v.x/2,hpt.y);
			if (v.x < 0)
			{
				canvas.graphics.lineTo(hpt.x+10,hpt.y);
				head.rotation = -90;
			}
			else
			{
				canvas.graphics.lineTo(hpt.x-10,hpt.y);
				head.rotation = 90;
			}
		}
		canvas.graphics.lineStyle();
		if (pic!=null) pic.drawOn(canvas);	// draws the arrow pic
	}//endfunction
		
	//=============================================================================
	// 
	//=============================================================================
	public function onMouseDown():void
	{
		var mx:Number = canvas.stage.mouseX;
		var my:Number = canvas.stage.mouseY;
		if (tail.hitTestPoint(mx,my))	tail.startDrag();
		
		canvas.addEventListener(Event.ENTER_FRAME, update);
		canvas.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function onMouseUp(ev:Event=null):void
	{
		tail.stopDrag();
		update();
		canvas.removeEventListener(Event.ENTER_FRAME, update);
		canvas.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
	}//endfunction
	
}//endfunction

class ProjProperties
{
	public var saveId:String = "";
	public var name:String = "默认方案名称";
	public var style:String = "默认风格";
	public var type:String = "默认类型";
	public var project:String = "项目名";
	public var address:String = "详细地址";
	public var serial:String = "编号";
	public var area:String = "面积";
	public var details:String = "户型详情";
	public var sheng:String = "---";
	public var shi:String = "---";
	public var qu:String = "---";
	public var form:String = "4:3";
	
	public var lastModify:String = "";
	
	
	public function ProjProperties():void
	{
		updateLastModifyDate();
	}
	
	public function updateLastModifyDate():void
	{
		var dat:Date = new Date();
		lastModify = dat.getFullYear() + "年" + (dat.getMonth()+1) + "月" + (dat.getDate())+"日";
	}//endfunction
	
	public function clone():ProjProperties
	{
		var p:ProjProperties = new ProjProperties();
		p.saveId = saveId;
		p.name = name;
		p.style = style;
		p.type = type;
		p.form = form;
		p.project = project;
		p.address = address;
		p.serial = serial;
		p.area = area;
		p.details = details;
		p.sheng = sheng;
		p.shi = shi;
		p.qu = qu;
		p.form = form;
		p.lastModify = lastModify;
		return p;
	}
}//endfunction

class LHSMenu
{
	public var canvas:Sprite = null;
	public var Spaces:Vector.<Space> = null;	// list of spaces
	public var Pages:Vector.<Page> = null;		// 
	public var selected:Page = null;
	public var projProperties:ProjProperties = null;
	
	private var marg:int = 10;
	private var bw:int = 120;

	private var msk:Sprite = null;
	private var con:Sprite = null;				// containing all the btns
	private var scroll:Sprite = null;
	
	private var createSpaceBtn:Sprite = null;
	
	private var dragging:DisplayObject = null;
	//=============================================================================
	// 
	//=============================================================================
	public function LHSMenu():void
	{
		projProperties = new ProjProperties();
		
		Spaces = new Vector.<Space>();
		Pages = new Vector.<Page>();
		Spaces.push(new Space());				// create new space
		selected = Spaces[0].Pages[0];
		
		canvas = new Sprite();					// main container
		
		con = new Sprite();						// container of buttons
		con.x = 2;
		con.y = marg;
		canvas.addChild(con);
		
		msk = new Sprite();						// mask for con
		msk.x = 2;
		msk.y = marg;
		canvas.addChild(msk);
		con.mask = msk;
		
		scroll = new Sprite();					// scrollbar for 
		canvas.addChild(scroll);
		scroll.addChild(new Sprite());
		(Sprite)(scroll.getChildAt(0)).buttonMode = true;
		
		createSpaceBtn = new Sprite();			// btn to create new space
		drawStripedRect(createSpaceBtn,0,0,120,120,0xEAEAEA,0xE9E9E9);
		var ico:Sprite = new IcoNewPage();
		ico.x = (createSpaceBtn.width-ico.width)/2;
		ico.y = (createSpaceBtn.height-ico.height)/2;
		createSpaceBtn.addChild(ico);
		
		canvas.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
		canvas.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		function addedHandler(ev:Event):void
		{
			canvas.removeEventListener(Event.ADDED_TO_STAGE, addedHandler);
			canvas.stage.addEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
		}
		canvas.addEventListener(Event.ADDED_TO_STAGE, addedHandler);
		enterFrameHandler(null);

	}//endconstr
	
	//=============================================================================
	// 
	//=============================================================================
	public function updateSpaces(Spcs:Vector.<Space>):void
	{
		trace("LHSMenu.updateSpaces()");
		while (con.numChildren>0) con.removeChildAt(0);	// clear off prev btns
		Spaces = Spcs;
		while (Pages.length>0)
			Pages.pop();
		for (var i:int=0; i<Spaces.length; i++)
		{
			for (var k:int=0; k<Spaces[i].Pages.length; k++)
			{
				selected = Spaces[i].Pages[k];
				Pages.push(selected);
			}
		}
	}//endfunction
	
	//=============================================================================
	// returns the parent space of given page, or null if not found
	//=============================================================================
	public function parentSpace(page:Page):Space
	{
		for (var i:int=0; i<Spaces.length; i++)
			if (Spaces[i].Pages.indexOf(page)!=-1)
				return Spaces[i];
		
		return null;
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	private function enterFrameHandler(ev:Event):void
	{
		var i:int;
		var ppy:int=0;
		
		// ----- update Pages if Spaces has changed -----------------
		var p:int=0;
		var rebuildPages:Boolean = false;
		for (i=0; i<Spaces.length && !rebuildPages; i++)
			for (var k:int=0; k<Spaces[i].Pages.length && !rebuildPages; k++)
			{
				if (Pages.length<=p || Pages[p]!=Spaces[i].Pages[k])
					rebuildPages = true;
				p++;
			}	
		if (rebuildPages)
		{
			while (Pages.length>0)
				Pages.pop();
			for (i=0; i<Spaces.length; i++)
				for (k=0; k<Spaces[i].Pages.length; k++)
					Pages.push(Spaces[i].Pages[k]);
		}
		
		// ----- update icons if pagesIcons changed -----------------
		if (con.numChildren!=Spaces.length+1)
		{
			for (i=0; i<Spaces.length; i++)
			{
				var btn:Sprite = Spaces[i].refreshLHSIco();
				btn.y = ppy;
				ppy+= Spaces[i].icoHeight+marg;
				if (con.contains(btn))
					con.setChildIndex(btn,i);
				else
					con.addChildAt(btn,i);
			}
			
			// clear off excess btns
			while (con.numChildren>Spaces.length) con.removeChildAt(con.numChildren-1);
			
			// the make new space btn
			createSpaceBtn.y = ppy;
			con.addChild(createSpaceBtn);
			resize(msk.height+marg*2);	// to refresh scrollbar
		}
		
		// ----- enable dragging interraction ----------------------
		ppy=0;
		var bar:Sprite = (Sprite)(scroll.getChildAt(0));
		if (dragging == null)	
		{}
		else if (dragging == bar)
			con.y = marg - bar.y / msk.height * con.height;
		// ----- dragging page over to new space
		else if (dragging is Bitmap)
		{
			trace(dragging.parent);
			var pageIco:Sprite = (Sprite)(dragging.parent);	// page within space
			for (i=0; i<con.numChildren-1; i++)
			{
				btn = (Sprite)(con.getChildAt(i));
				if (!btn.contains(pageIco) && 		// dragged over to new space
					btn.y<con.mouseY && btn.y+btn.height>con.mouseY)
				{
					var oldSpace:Space = Spaces[con.getChildIndex(pageIco.parent)];
					var newSpace:Space = Spaces[i];
					var page:Page = null;
					for (p=oldSpace.Pages.length-1; p>-1; p--)
						if (oldSpace.Pages[p].ico == pageIco)
							page = oldSpace.Pages[p];
					
					trace("oldSpace:" + con.getChildIndex(pageIco.parent) + "  newSpace:" + i + "  page=" + page);
					if (page != null)
					{
						oldSpace.removePage(page);
						newSpace.addPage(page);
						dragging = null;
					}
				}
			}
		}
		// ----- dragging space up down
		else
		{
			dragging.y = con.mouseY - dragging.height / 2;	// follow mouse drag	
			if (con.contains(dragging))			// dragging space
			{
				for (i=0; i<con.numChildren-1; i++)
				{
					btn = (Sprite)(con.getChildAt(i));
					var testY:int = ppy+marg+btn.height/2;	// button position
					ppy += btn.height+marg; 
					if (btn!=dragging &&		// if dragging overlaps button position
						testY>dragging.y && testY<dragging.y+dragging.height)
					{
						var spc:Space = Spaces[con.getChildIndex(dragging)];
						Spaces[con.getChildIndex(dragging)] = Spaces[i];
						Spaces[i] = spc;
						con.swapChildrenAt(con.getChildIndex(dragging),i);
						i=con.numChildren;		// end chk
					}
				}
			}
		}
		
		// ----- position buttons -----------------------------------
		ppy = 0;
		for (i=0; i<con.numChildren; i++)
		{
			btn = (Sprite)(con.getChildAt(i)); 
			if (btn!=dragging)
			{
				btn.alpha = 1;
				btn.y = ppy+marg;
			}
			if (i < Spaces.length)
				ppy += Spaces[i].icoHeight+marg;
			else
				ppy += btn.height+marg;
		}
		
		// ----- detect roll over -----------------------------------
		if (canvas.stage!=null)
		for (i=con.numChildren-1; i>-1; i--)
		{
			btn = (Sprite)(con.getChildAt(i));
			if (btn.hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
			{
				var A:Array = btn.filters;
				if (A.length==0)
					btn.filters=[new GlowFilter(0x000000,1,4,4,2)];
				else if ((GlowFilter)(A[0]).strength<1)
					(GlowFilter)(A[0]).strength+=0.1;
			}
			else
			{
				if (btn.filters.length>0)
				{
					A = btn.filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=0.1;
					else 
						A = null;
					btn.filters = A;
				}
			}	
		}
	}//endfunction
	
	//=============================================================================
	// release page being dragged
	//=============================================================================
	private function mouseUpHandler(ev:Event):void
	{
		if (dragging==scroll.getChildAt(0))
			(Sprite)(scroll.getChildAt(0)).stopDrag();
		dragging = null;
	}
	
	//=============================================================================
	// create a new page or go to the page on click
	//=============================================================================
	private function mouseDownHandler(ev:Event):void
	{
		//ImageTool.prn("LHS.mouseDownHandler");
		var mx:Number = canvas.stage.mouseX;
		var my:Number = canvas.stage.mouseY;
		var space:Space;
		
		// ----- create new space if new page button clicked
		if (con.getChildAt(con.numChildren-1).hitTestPoint(mx,my))
		{
			space = new Space();
			Spaces.push(space);
			return;
		}
		// ----- allow scrollbar dragging -------------------------
		if (scroll.getChildAt(0).hitTestPoint(mx,my))
		{
			dragging = scroll.getChildAt(0);
			(Sprite)(dragging).startDrag(false,new Rectangle(0,0,0,msk.height-dragging.height));
			return;
		}
		// ----- clicked on page thumb ----------------------------
		for (var i:int=con.numChildren-2; i>-1; i--)
		{
			var btn:Sprite = (Sprite)(con.getChildAt(i));
			if (btn.hitTestPoint(mx,my))
			{
				var spc:Space = Spaces[i];
				if (Spaces.length>1 && spc.pointHitsCloseBtn())
				{
					Spaces.splice(i,1);	// delete page if cross is clicked
					selected = Spaces[Math.max(0,i-1)].Pages[0];
				}
				else if (spc.pointHitsTextfield())
				{}
				else if (spc.pointHitsAddBtn())
				{
					spc.addPage();
					enterFrameHandler(null);
					resize(msk.height+marg*2);	// to refresh scrollbar
				}
				else if (spc.chkHitThumbCloseBtns())
				{
					// destroy thumbnails
				}
				else
				{
					var nsel:Page = spc.chkHitThumb();
					if (nsel != null)
					{
						selected = nsel;
						spc.dragPage(nsel);
						dragging = nsel.thumb;
					}
					else 			dragging = btn;		// dragging over page thumb
				}
			}
		}
		
	}//endfunction
	
	//=============================================================================
	// resizes this menu
	//=============================================================================
	public function resize(h:int):void
	{
		trace("LHS.resize("+h+")");
		msk.graphics.clear();
		msk.graphics.beginFill(0x000000,1);
		msk.graphics.drawRect(0,0,bw+10,h-marg*2);
		msk.graphics.endFill();
		
		scroll.graphics.clear();
		drawStripedRect(scroll,0,0,4,h-marg*2,0xFFFFFF,0xF6F6F6,5,10);
		scroll.y = marg;
		scroll.x = msk.width;
		
		var bh:Number = Math.min(1,(h-marg*2)/con.height)*(h-marg*2);
		var bar:Sprite = (Sprite)(scroll.getChildAt(0));
		bar.graphics.clear();
		drawStripedRect(bar,0,0,4,bh,0x333355,0x373757,5,10);
	}
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	public static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,rnd,rnd);
		s.graphics.endFill();
		
		return s;
	}//endfunction 
}//endclass

class Space
{
	public var title:String = null;
	public var Pages:Vector.<Page> = null;
	public var lhsIco:Sprite = null;
	public var icoHeight:int = 0;
	
	//-------------------------------------------------------------------------
	// constr
	//-------------------------------------------------------------------------
	public function Space()
	{
		title = "新空间";
		Pages = new Vector.<Page>();
		Pages.push(new Page("new page"));
		
		refreshLHSIco();
	}//endfunction
	
	//-------------------------------------------------------------------------
	// convenience function to generate LHS space icons
	//-------------------------------------------------------------------------
	public function refreshLHSIco():Sprite
	{
		var marg:int = 5;
		
		if (lhsIco==null)
		{
			lhsIco = new Sprite();
			var tf:TextField = PPTool.utils.createInputText(function(txt:String):void 
															{
																title = txt;
																tf.x = (lhsIco.width-tf.width)/2;
															},
															title);
			lhsIco.addChild(tf);
			
			var btns:Sprite = new Sprite();
			btns.buttonMode = true;
			lhsIco.addChild(btns);
						
			var cross:Sprite = new IcoSpaceRemove();
			btns.addChild(cross);
			
			var plus:Sprite = new IcoPageAdd();
			btns.addChild(plus);
			lhsIco.buttonMode = true;
		}
		
		var oldH:int = lhsIco.height;
		
		// ----- the btns and label text for this space
		btns = lhsIco.getChildAt(lhsIco.numChildren-1) as Sprite;	// buttons layer
		tf = lhsIco.getChildAt(lhsIco.numChildren-2) as TextField;	// space label textfield 
		cross = btns.getChildAt(btns.numChildren-2) as Sprite;		// 2nd last child in btns is delete space
		plus = btns.getChildAt(btns.numChildren-1) as Sprite;		// last child in btns is add page
		
		// ----- if not enough buttons add more
		while (btns.numChildren<Pages.length+2)
			btns.addChildAt(new IcoPageRemove(),0);
		while (btns.numChildren>Pages.length+2)
			btns.removeChildAt(0);
			
		// ----- chk and refresh pages within this space
		var curH:int = tf.height+marg*3;
		for (var i:int=0; i<Pages.length; i++)
		{
			var pg:Page = Pages[i];
			if (pg.ico.parent!=lhsIco)
				lhsIco.addChildAt(pg.ico,i);
			else if (lhsIco.getChildIndex(pg.ico)!=i)
				lhsIco.setChildIndex(pg.ico,i);
			pg.ico.x = marg;										// position page ico
			pg.ico.y = curH;
			var crossBtn:DisplayObject = btns.getChildAt(i);		// align page thumb clos button
			crossBtn.x = pg.ico.x+pg.ico.width-crossBtn.width;
			crossBtn.y = pg.ico.y;
			curH = pg.ico.y+pg.ico.height+5;
		}
		tf.text = title;
		//curH += tf.height+marg;
		plus.y = curH;
		curH += plus.height+marg;
			
		// ----- redraw the lhsIco base
		if (curH!=oldH)
		{
			cross.x = 0;
			plus.x = 0;
			lhsIco.graphics.clear();
			tf.x = (lhsIco.width-tf.width)/2;
			tf.y = 5;
			plus.x = (lhsIco.width-plus.width)/2;
			lhsIco.graphics.beginFill(0xEBEBED,1);					// draw base rect
			lhsIco.graphics.drawRect(0,0,lhsIco.width+marg*2,curH);	
			lhsIco.graphics.beginFill(0xBFC3CE,1);					// draw top bar rect
			lhsIco.graphics.drawRect(0,0,lhsIco.width,tf.height+marg*2);
			cross.x = lhsIco.width-cross.width-marg/4;				// position close btn
			cross.y = marg;
		}
		
		// ----- remove tmbs of pages not belonging to this space
		while (lhsIco.numChildren>Pages.length+2)
			lhsIco.removeChildAt(lhsIco.numChildren-3);
		
		//ImageTool.prn("refreshLHSIco() lhsIco.numChildren="+lhsIco.numChildren+"  h="+lhsIco.height);
		
		icoHeight = curH;
		
		return lhsIco;
	}//endfunction
	
	//-------------------------------------------------------------------------
	// convenience function 
	//-------------------------------------------------------------------------
	public function pointHitsTextfield():Boolean
	{
		if (lhsIco.stage == null) return false;
		for (var i:int = 0; i < Pages.length; i++)
		{
			var ico:Sprite = Pages[i].ico;
			for (var j:int = 0; j < ico.numChildren; j++)
			if (ico.getChildAt(j) is TextField && 
				ico.getChildAt(j).hitTestPoint(lhsIco.stage.mouseX, lhsIco.stage.mouseY))
				return true;
		}
		return lhsIco.getChildAt(lhsIco.numChildren-2).hitTestPoint(lhsIco.stage.mouseX,lhsIco.stage.mouseY);
	}//endfunction
	
	//-------------------------------------------------------------------------
	// convenience function 
	//-------------------------------------------------------------------------
	public function pointHitsCloseBtn():Boolean
	{
		if (lhsIco.stage==null) return false;
		var btn:Sprite = lhsIco.getChildAt(lhsIco.numChildren-1) as Sprite;
		return btn.getChildAt(btn.numChildren-2).hitTestPoint(lhsIco.stage.mouseX,lhsIco.stage.mouseY);
	}//endfunction
	
	//-------------------------------------------------------------------------
	// convenience function 
	//-------------------------------------------------------------------------
	public function pointHitsAddBtn():Boolean
	{
		if (lhsIco.stage==null) return false;
		var btn:Sprite = lhsIco.getChildAt(lhsIco.numChildren-1) as Sprite;
		return btn.getChildAt(btn.numChildren-1).hitTestPoint(lhsIco.stage.mouseX,lhsIco.stage.mouseY);
	}//endfunction
	
	//-------------------------------------------------------------------------
	// convenience function 
	//-------------------------------------------------------------------------
	public function chkHitThumbCloseBtns():Boolean
	{
		if (lhsIco.stage==null) return false;
		if (Pages.length<2)		return false;
		var btns:Sprite = lhsIco.getChildAt(lhsIco.numChildren-1) as Sprite;
		for (var i:int=0; i<btns.numChildren-2; i++)
			if (btns.getChildAt(i).hitTestPoint(lhsIco.stage.mouseX,lhsIco.stage.mouseY))
			{
				Pages.splice(i,1);
				refreshLHSIco();
				return true;
			}
		return false;
	}//endfunction
	
	//-------------------------------------------------------------------------
	// convenience function 
	//-------------------------------------------------------------------------
	public function chkHitThumb():Page
	{
		var hitIdx:int=-1;
		for (var i:int=0; i<lhsIco.numChildren-2; i++)
			if (lhsIco.getChildAt(i).hitTestPoint(lhsIco.stage.mouseX,lhsIco.stage.mouseY))
				return Pages[i];
		return null;
	}//endfunction
	
	//-------------------------------------------------------------------------
	// allows reordering of pages in Space by dragging
	//-------------------------------------------------------------------------
	private var stopDragPage:Function = null;
	public function dragPage(page:Page):void
	{	
		function enterFrameHandler(ev:Event):void
		{
			page.ico.y = lhsIco.mouseY - page.ico.height / 2;
			
			for (var i:int = 0; i < Pages.length; i++)
			{
				var pp:Page = Pages[i];
				if (pp != page && pp.ico.y < lhsIco.mouseY && pp.ico.y + pp.ico.height > lhsIco.mouseY)
				{	// swap positions!
					Pages[Pages.indexOf(page)] = pp;
					Pages[i] = page;
					refreshLHSIco();
					i = Pages.length;
				}
			}//endfor
		}//endfunction
		lhsIco.addEventListener(Event.ENTER_FRAME, enterFrameHandler);
		
		function stopHandler(ev:Event):void
		{
			lhsIco.removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
			lhsIco.stage.removeEventListener(MouseEvent.MOUSE_UP, stopHandler);
			refreshLHSIco();
		}//endfunction
		lhsIco.stage.addEventListener(MouseEvent.MOUSE_UP, stopHandler);
		
		stopDragPage =function():void
		{
			trace("stopDragPage");
			stopDragPage = null;
			stopHandler(null);
		}
	}//endfunction
	
	//-------------------------------------------------------------------------
	// convenience function 
	//-------------------------------------------------------------------------
	public function addPage(page:Page=null):void
	{
		if (page == null)
			Pages.push(new Page("new page"));
		else
			Pages.push(page);
		refreshLHSIco();
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function removePage(page:Page):void
	{
		if (Pages.indexOf(page) != -1)
		{
			Pages.splice(Pages.indexOf(page), 1);
			if (stopDragPage!=null) stopDragPage();
			refreshLHSIco();
		}
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function getMatchId():Array
	{
		var A:Array = [];
		for (var i:int=0; i<Pages.length; i++)
		for (var j:int=0; j<Pages[i].Pics.length; j++)
			if (Pages[i].Pics[j].data!=null)
				A.push(Pages[i].Pics[j].id);
		return A;
	}//endfunction
	
}//endclass

class Page
{
	public var title:String = null;				// title of the page
	public var Pics:Vector.<Image> = null;		// pics contents of the page
	public var Txts:Vector.<TextField> = null;	// text labeling of the page
	public var Arrows:Vector.<Arrow> = null;	// arrows labelling of the page
	public var ico:Sprite = null;
	public var bg:BitmapData = null;
	public var bgUrl:String = null;
	
	public var thumb:Bitmap = null;				// small capture of page
	public var imageUploaded:Boolean = false;	// md5 of the screen capture
	public var pageId:int = -1;					// unique id of this page
	public var image:BitmapData = null;			// the page capture data
	
	public static var uniqueCnt:int = 0;
	
	public function Page(_title:String):void
	{
		pageId = uniqueCnt++;
		title = _title;
		thumb = new Bitmap(new BitmapData(110,80,false,0xFFFFFF));
		Pics = new Vector.<Image>();
		Txts = new Vector.<TextField>();
		Arrows = new Vector.<Arrow>();
		ico = new Sprite();
		ico.addChild(thumb);
		var tf:TextField = PPTool.utils.createText(title);
		tf.y = thumb.height;
		tf.x = (thumb.width-tf.width)/2;
		ico.addChild(tf);
		
		ico.addEventListener(Event.ADDED_TO_STAGE,function(ev:Event):void 
		{
			while (ico.numChildren>1) ico.removeChildAt(1);
			var tf:TextField = PPTool.utils.createInputText(function():void 
			{
				title = tf.text;
				tf.x = (thumb.width-tf.width)/2;
			},title);
			tf.y = thumb.height;
			tf.x = (thumb.width-tf.width)/2;
			ico.addChild(tf);
		});
	}//endconstr
}//endclass

class RHSMenu
{
	public var canvas:Sprite = null;
	private var dat:Object = null;
	private var Btns:Vector.<Sprite> = null;
	private var con:Sprite = null;	
	private var pageBtns:Sprite = null;
	private var sideBtns:Sprite = null;
	private var sideFns:Vector.<Function> = null;
	
	private var marg:int = 6;
	private var bw:int = 66;
	private var bh:int = 76;
	private var height:int = 600; 
	private var category:int=0;			// current category being displayed
	private var page:int=0;				// current page in category
	
	private var curTab:int = 0;
	
	private var getProductItemsData:Function = null;
	
	private var baseUrl:String = "";
	private var userToken:String;
	
	public var clickCallBack:Function = null;	// function to return 
	public var updateCanvas:Function = null;
	
	//=============================================================================
	// Constr
	//=============================================================================
	public function RHSMenu(token:String,getProdFn:Function):void
	{
		baseUrl = PPTool.baseUrl;
		userToken = token;
		getProductItemsData = getProdFn;
		
		canvas = new Sprite();					// main container
		Btns = new Vector.<Sprite>();			// list of all buttons
		
		// ----- create side selection tabs
		setTabs(Vector.<String>(["个\n人\n素\n材","我\n的\n搭\n配","所\n有\n搭\n配"]),
				Vector.<Function>([	function():void { loadAssetsType(1);	curTab = 0; },
									function():void { loadCombo("0");	curTab = 1; },
									function():void { loadCombo("1");	curTab = 2; }]));
		
		con = new Sprite();						// container of buttons
		con.x = sideBtns.width+marg+5;
		con.y = marg;
		canvas.addChild(con);
		
		pageBtns = new Sprite();
		pageBtns.buttonMode = true;
		canvas.addChild(pageBtns);
		
		canvas.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
		canvas.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		canvas.addEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
		
		loadAssetsType(1);		// default load assets 1
	}//endconstr
	
	//=============================================================================
	// 
	//=============================================================================
	private function setTabs(sideLabels:Vector.<String>,fns:Vector.<Function>):void
	{
		trace("setTabs");
		if (sideBtns==null)	
			sideBtns = new Sprite();
		else
			while (sideBtns.numChildren>0)
				sideBtns.removeChildAt(0);
		
		sideFns = fns;
		
		var offY:int=0;
		for (var i:int=0; i<sideLabels.length; i++)
		{
			var btn:Sprite= new Sprite();
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			tf.text = sideLabels[i];
			tf.x = tf.y = 5;
			btn.addChild(tf);
			drawStripedRect(btn,0,0,tf.width+10,tf.height+10,0xAAAAAA,0xA6A6A6,5,10);
			btn.y = offY;
			offY += btn.height;
			sideBtns.addChild(btn);
			btn.buttonMode = true;
			btn.mouseChildren = false;
			btn.filters = [new GlowFilter(0x000000,1,4,4,1)];
		}
		canvas.addChildAt(sideBtns,0);
	}//endfunction
	
	//=============================================================================
	// loads specified asset type, external loaded pics
	//=============================================================================
	private function loadCombo(share:String="0"):void
	{
		trace("loadCombo");
		sideBtns.visible = false;
		var ldr:URLLoader = new URLLoader();
		var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=scheme&c=match&m=index&isshare="+share+"&token="+userToken);
		ldr.load(req);
		ldr.addEventListener(Event.COMPLETE, onComplete);  
		function onComplete(e:Event):void
		{	// ----- when received data from server
			var o:Object = JSON.parse(ldr.data);
			var projs:Array = o.projects;
			Btns = new Vector.<Sprite>();
			dat = projs;
			for (var i:int=0; i<projs.length; i++)
			{
				var proj:Object = projs[i];
				proj.pic = proj.image;
				var s:Sprite = new Sprite();
				var tf:TextField = new TextField();
				tf.wordWrap = false;
				tf.autoSize = "left";
				tf.text = proj.name;
				if (tf.width>bw)
				{
					tf.wordWrap = true;
					tf.width = bw;
				}
				tf.selectable = false;
				tf.y = bh-tf.height;
				s.addChild(tf);
				drawStripedRect(s,0,0,bw,bh-tf.height,0xFFFFFF,0xF6F6F6,20,10);
				s.buttonMode = true;
				s.mouseChildren = false;
				Btns.push(s);
			}
			pageTo(page);
			
			// ----- start loading the pics 
			var lidx:int=0;
			function loadNext():void
			{
				if (lidx < dat.length)
				{
					var picUrl:String = baseUrl + "thumb.php?src="+dat[lidx].pic+"&w=100"
					//var picUrl:String = baseUrl + dat[lidx].pic;
					//if (dat[lidx].thumb200 != null) 			picUrl += dat[lidx].thumb200;
					//else if (dat[lidx].thumb400 != null)		picUrl += dat[lidx].thumb400;
					//trace("loading "+picUrl);
					MenuUtils.loadAsset(picUrl,function(pic:Bitmap):void
					{
						var tf:TextField = (TextField)(Btns[lidx].getChildAt(0));
						if (picUrl == null) pic = new Bitmap(new BitmapData(bw, bh - tf.height, false, 0xAA0000));
						pic.width = bw;
						pic.height = bh-tf.height;
						if (Btns.length>lidx)
						{
							Btns[lidx].addChild(pic);
							dat[lidx].bmd = pic.bitmapData;
							tf.x = (pic.width-tf.width)/2;
							lidx++;
							loadNext();
						}
					});
				}
				else
					sideBtns.visible = true;
			} //endfunction
			if (dat!=null) loadNext();
			
		}//endfunction
		
	}//endfunction
	
	//=============================================================================
	// loads specified asset type, external loaded pics
	//=============================================================================
	private function loadAssetsType(tp:int=1):void
	{
		trace("loadAssetsType");
		
		//sideBtns.visible = false;
		
		var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=user&c=photo&type="+tp+"&token="+userToken);
		var ldr:URLLoader = new URLLoader(req);
		req.method = "post";  
		var vars:URLVariables = new URLVariables();  
		vars.token = userToken;  
		req.data = vars;
		ldr.load(req);
		ldr.addEventListener(Event.COMPLETE, onComplete);  
		function onComplete(e:Event):void
		{	// ----- when received data from server
			//trace(ldr.data);
			var o:Object = JSON.parse(ldr.data);
			dat = o.data;
			
			// ----- fill with new Btns
			Btns = new Vector.<Sprite>();
			if (o.data!=null)
			for (var i:int=0; i<o.data.length; i++)
			{
				var s:Sprite = new Sprite();
				var tf:TextField = new TextField();
				tf.wordWrap = false;
				tf.autoSize = "left";
				tf.text = o.data[i].photoname;
				tf.selectable = false;
				tf.y = bh-tf.height;
				tf.border
				s.addChild(tf);
				drawStripedRect(s,0,0,bw,bh-tf.height,0xFFFFFF,0xF6F6F6,20,10);
				s.buttonMode = true;
				s.mouseChildren = false;
				Btns.push(s);
			}
			pageTo(page);
			
			// ----- start loading the pics 
			var lidx:int=0;
			function loadNext():void
			{
				if (o.data != null && lidx < o.data.length)
				{
					var picUrl:String = baseUrl + "thumb.php?src="+o.data[lidx].pic+"&w=100"
					//var picUrl:String = baseUrl + o.data[lidx].pic;
					//if (o.data[lidx].thumb200 != null) 			picUrl += o.data[lidx].thumb200;
					//else if (o.data[lidx].thumb400 != null)		picUrl += o.data[lidx].thumb400;
					//trace("loading "+picUrl);
					MenuUtils.loadAsset(picUrl,function(pic:Bitmap):void
					{
						if (lidx >= Btns.length)	return;
						var tf:TextField = (TextField)(Btns[lidx].getChildAt(0));
						pic.width = bw;
						pic.height = bh-tf.height;
						Btns[lidx].addChild(pic);
						o.data[lidx].bmd = pic.bitmapData;
						tf.x = (pic.width-tf.width)/2;
						lidx++;
						loadNext();
					});
				}
				//if (dat != null && lidx >= dat.length)	sideBtns.visible = true;
			} //endfunction
			loadNext();
		}
	}//endfunction
	
	//=============================================================================
	// loads specified asset type, external loaded pics
	//=============================================================================
	public function loadProducts():void
	{
		isNormal = false;
		var A:Array = getProductItemsData();
		trace("loadProducts data:"+A.length);
		dat = A;
		sideBtns.visible = false;
		
		// ----- fill with new Btns
		Btns = new Vector.<Sprite>();
		if (A!=null)
		for (var i:int=0; i<A.length; i++)
		{
			var s:Sprite = new Sprite();
			var tf:TextField = new TextField();
			tf.wordWrap = false;
			tf.autoSize = "left";
			if (A[i]!= null)
			{
				if (A[i] is String) A[i] = JSON.parse(A[i]);
				if (A[i] is String) trace("loadProductsERROR! A["+i+"]="+A[i]);
				tf.text = A[i].name;
			}
			else
				tf.text = "???";
			tf.selectable = false;
			tf.y = bh-tf.height;
			s.addChild(tf);
			drawStripedRect(s,0,0,bw,bh-tf.height,0xFFFFFF,0xF6F6F6,20,10);
			s.buttonMode = true;
			s.mouseChildren = false;
			Btns.push(s);
		}
		pageTo(page);
		
		// ----- start loading the pics 
		var lidx:int=0;
		function loadNext():void
		{
			if (lidx < A.length)
			{
				if (A[lidx] == null)
				{
					var pic:Bitmap = new Bitmap(new BitmapData(50, 50, false, 0xFF0000));
					var tf:TextField = (TextField)(Btns[lidx].getChildAt(0));
					pic.width = bw;
					pic.height = bh-tf.height;
					Btns[lidx].addChild(pic);
					A[lidx].bmd = pic.bitmapData;
					tf.x = (pic.width-tf.width)/2;
					lidx++;
					loadNext();
				}
				else
				{
					var picUrl:String = baseUrl + A[lidx].pic;
					if (A[lidx].thumb200 != null) 			picUrl += A[lidx].thumb200;
					else if (A[lidx].thumb400 != null)		picUrl += A[lidx].thumb400;
					MenuUtils.loadAsset(picUrl,function(pic:Bitmap):void
					{	// create thumbnail of loaded pic
						var tf:TextField = (TextField)(Btns[lidx].getChildAt(0));
						var npic:Bitmap = new Bitmap(new BitmapData(bw, bh - tf.height, true, 0));
						npic.bitmapData.draw(pic, new Matrix(npic.width / pic.width, 0, 0, npic.height / pic.height));
						//pic.width = bw;
						//pic.height = bh-tf.height;
						Btns[lidx].addChild(npic);
						A[lidx].bmd = pic.bitmapData;
						tf.x = (npic.width-tf.width)/2;
						lidx++;
						loadNext();
					});
				}
			}
		} //endfunction
		loadNext();
		
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	private	var isNormal:Boolean = true;
	public function showNormal():void
	{
		trace("showNormal");
		if (isNormal) return;
		isNormal = true;
		trace("showNormal!!");
		sideBtns.visible = true;
		if (curTab==0)	loadAssetsType(1);
		if (curTab==1)	loadCombo("0");
		if (curTab==2)	loadCombo("1");
	}//endfunction
	
	//=============================================================================
	// does the stupid highlighting
	//=============================================================================
	private function enterFrameHandler(ev:Event):void
	{
		var i:int;
		
		// ----- detect roll over -----------------------------------
		if (canvas.stage!=null)
		for (i=con.numChildren-1; i>-1; i--)
		{
			var btn:Sprite = (Sprite)(con.getChildAt(i));
			if (btn.hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
			{
				var A:Array = btn.filters;
				if (A.length==0)
					btn.filters=[new GlowFilter(0x000000,1,4,4,1)];
				else if ((GlowFilter)(A[0]).strength<1)
					(GlowFilter)(A[0]).strength+=0.1;
			}
			else
			{
				if (btn.filters.length>0)
				{
					A = btn.filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=0.1;
					else 
						A = null;
					btn.filters = A;
				}
			}	
		}
	}//endfunction
	
	//=============================================================================
	// create a new page or go to the page on click
	//=============================================================================
	private function mouseDownHandler(ev:Event):void
	{
		// ----- thumbnail pressed
		if (con.hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
		{
			for (var i:int=0; i<Btns.length; i++)
				if (Btns[i].parent==con && Btns[i].hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
				{
					var img:Image = new Image(dat[i].id, dat[i].pic, dat[i].bmd);	// each dat[i] is project elem
					MenuUtils.loadAsset(baseUrl+img.url, function(bmp:Bitmap):void 
					{ 
						if (Math.abs((img.Corners[1].x-img.Corners[0].x)+(img.Corners[2].x-img.Corners[3].x) - img.bmd.width*2) < 1 &&
							Math.abs((img.Corners[3].y-img.Corners[0].y)+(img.Corners[2].y-img.Corners[1].y) - img.bmd.height*2) < 1)
							img.setBmd(bmp.bitmapData);
						else
							img.swapBmd(bmp.bitmapData);
						if (updateCanvas != null)	updateCanvas();
					} );
					if (dat[i].data!=null)
						img.data = JSON.parse(dat[i].data).layers;
					if (clickCallBack!=null)	clickCallBack(img);
				}
		}
	}//endfunction
	
	//=============================================================================
	// create a new page or go to the page on click
	//=============================================================================
	private function mouseUpHandler(ev:Event):void
	{
		// ----- if side button pressed swap category 
		if (sideBtns.visible && sideBtns.hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
			for (var i:int=0; i<sideBtns.numChildren; i++)
			{
				var btn:Sprite = (Sprite)(sideBtns.getChildAt(i));
				if (btn.hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
				{
					btn.graphics.clear();
					drawStripedRect(btn,0,0,btn.getChildAt(0).width+10,btn.getChildAt(0).height+10,0xFFFFFF,0xF6F6F6,5,10);
					trace("tab "+i);
					sideFns[i]();
				}
				else
				{
					btn.graphics.clear();
					drawStripedRect(btn,0,0,btn.getChildAt(0).width+10,btn.getChildAt(0).height+10,0xAAAAAA,0xA6A6A6,5,10);
				}
			}
		
		// ----- switch page according to page buttons
		var icosPerPage:int = Math.floor((height-marg*2)/(bh+marg))*3;
		var totalPages:int = Math.ceil(Btns.length/icosPerPage);
		if (pageBtns.hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
		{
			pageTo(Math.round(pageBtns.mouseX/pageBtns.width*totalPages));
		}
		
		
	}//endfunction
	
	//=============================================================================
	// go to page number
	//=============================================================================
	public function pageTo(idx:int):void
	{
		if (idx<0)	idx = 0;
		var icosPerPage:int = Math.floor((height-marg*5)/(bh+marg))*3;
		var totalPages:int = Math.ceil(Btns.length/icosPerPage);
		if (totalPages<=0) totalPages=1;
		if (idx>totalPages-1)	idx = totalPages-1;
		
		while (con.numChildren>0)	con.removeChildAt(0);
		for (var i:int=idx*icosPerPage; i<Math.min(Btns.length,(idx+1)*icosPerPage); i++)
		{
			var btn:Sprite = Btns[i];
			btn.x = (i%3)*(bw+marg);
			btn.y = int((i-idx*icosPerPage)/3)*(bh+marg);
			con.addChild(btn);
		}
		
		pageBtns.graphics.clear();
		for (i=0; i<totalPages; i++)
		{
			if (i==idx)
				pageBtns.graphics.beginFill(0x999999,1);
			else
				pageBtns.graphics.beginFill(0x333333,1);
			pageBtns.graphics.drawRect(i*10,0,5,5);
			pageBtns.graphics.endFill();
		}
		pageBtns.y = height-pageBtns.height-10;
		pageBtns.x = 50;
		page = idx;
	}//endfunction	
	
	//=============================================================================
	// resizes this menu
	//=============================================================================
	public function resize(h:int):void
	{
		height = h;
		pageTo(page);
	}
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	public static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,rnd,rnd);
		s.graphics.endFill();
		
		return s;
	}//endfunction 
}//endclass

class Image
{
	public var Corners:Vector.<Point> = null;
	public var id:String = null;				// id of product
	public var url:String = null;				// url of pic 
	public var bmd:BitmapData = null;			// loaded bitmap data of pic
	public var data:Object = null;				// other data corresponding to this 
	
	//=============================================================================
	// 
	//=============================================================================
	public function Image(_id:String=null,_url:String=null,_bmd:BitmapData=null,px:Number=0,py:Number=0):void
	{
		id = _id;
		url = _url;
		if (Corners==null)
		Corners = Vector.<Point>([	new Point(),
									new Point(),
									new Point(),
									new Point()]);
		if (_bmd!=null)	setBmd(_bmd,px,py);
	}//endconstr
	
	//=============================================================================
	// draws
	//=============================================================================
	public function drawOn(s:Sprite):void
	{
		drawBmdWithin(bmd, s, Corners[0], Corners[1], Corners[2], Corners[3]);
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function setBmd(b:BitmapData,px:Number=0,py:Number=0):void
	{
		if (b == null) return;
		bmd = b;
		
		Corners = Vector.<Point>([	new Point(px-bmd.width/2,py-bmd.height/2),
									new Point(px+bmd.width/2,py-bmd.height/2),
									new Point(px+bmd.width/2,py+bmd.height/2),
									new Point(px-bmd.width/2,py+bmd.height/2)]);
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function swapBmd(b:BitmapData):void
	{
		bmd = b;
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function updateBranch():void
	{
	}//endfunction
	
	//=============================================================================
	// returns center of corner points
	//=============================================================================
	public function getCenter():Point
	{
		var pt:Point = new Point(0,0);
		for (var i:int=Corners.length-1; i>-1; i--)
		{
			pt.x+=Corners[i].x;
			pt.y+=Corners[i].y;
		}
		
		pt.x/=Corners.length;
		pt.y/=Corners.length;
		return pt;
	}//endfunction
	
	//=============================================================================
	// shift so that center of corner points is at x,y
	//=============================================================================
	public function centerTo(x:Number,y:Number):void
	{
		var cpt:Point = getCenter();
		var dx:Number = x-cpt.x;
		var dy:Number = y-cpt.y;
		for (var i:int=Corners.length-1; i>-1; i--)
		{
			Corners[i].x+=dx;
			Corners[i].y+=dy;
		}
	}//endfunction
	
	//=============================================================================
	// rotate around center by ang 
	//=============================================================================
	public function rotate(ang:Number):void
	{
		var cpt:Point = getCenter();
		for (var i:int=Corners.length-1; i>-1; i--)
		{
			var loc:Point = Corners[i].subtract(cpt);
			loc = new Point(loc.x*Math.cos(ang)+loc.y*Math.sin(ang) , loc.y*Math.cos(ang)-loc.x*Math.sin(ang));
			Corners[i] = loc.add(cpt);
		}
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	public function scale(sc:Number):void
	{
		var cpt:Point = getCenter();
		for (var i:int=Corners.length-1; i>-1; i--)
		{
			var loc:Point = Corners[i].subtract(cpt);
			loc.normalize(loc.length*sc);
			Corners[i] = loc.add(cpt);
		}
	}//endfunction
	
	//=============================================================================
	// draws given bitmap data within points ABCD clockwise arrangement
	// uv crop rect from 0 to 1
	//=============================================================================
	public static function drawBmdWithin(bmd:BitmapData,s:Sprite,A:Point,B:Point,C:Point,D:Point,divs:int=10,uvCrop:Rectangle=null):void
	{
		if (uvCrop == null)	uvCrop = new Rectangle(0, 0, 1, 1);
		
		var V:Vector.<Number> = new Vector.<Number>();
		var I:Vector.<int> = new Vector.<int>();
		var UV:Vector.<Number> = new  Vector.<Number>();
		
		for (var j:int=0; j<=divs; j++)
			for (var i:int=0; i<=divs; i++)
		{
			var rx:Number = i/divs;
			var ry:Number = j/divs;
			var pt1X:Point = new Point(A.x*(1-rx)+B.x*rx,A.y*(1-rx)+B.y*rx);
			var pt2X:Point = new Point(D.x*(1-rx)+C.x*rx,D.y*(1-rx)+C.y*rx);
			var pt:Point = new Point(pt1X.x*(1-ry)+pt2X.x*ry , pt1X.y*(1-ry)+pt2X.y*ry);
			V.push(pt.x,pt.y);
			UV.push(uvCrop.x + i / divs*uvCrop.width,
					uvCrop.y + j / divs*uvCrop.height);
		}//endfor
		
		for (j=0; j<divs; j++)
			for (i=0; i<divs; i++)
		{
			var off:int = divs+1;	//num of pts in a line
			// ----- draw the cell bounds
			
			var a:int = off*j + i;
			var b:int = off*j + i+1;
			var c:int = off*(j+1) + i+1;
			var d:int = off*(j+1) + i;
			I.push(a,b,c,   a,c,d);
		}
		
		s.graphics.beginBitmapFill(bmd,null,false,true);
		s.graphics.drawTriangles(V,I,UV);
		s.graphics.endFill();
	}//endfunction
}//endclass

class CropImage extends Image
{
	public var image:Image = null;
	public var uvCrop:Rectangle = null;
	
	//=============================================================================
	// 
	//=============================================================================
	public function CropImage(img:Image):void
	{
		image = img;
		id = img.id;
		url = img.url;
		data = img.data;
		
		// ----- 
		var b:Rectangle = getChildImageBounds();
		Corners = Vector.<Point>([	new Point(b.left,b.top),
									new Point(b.right,b.top),
									new Point(b.right,b.bottom),
									new Point(b.left, b.bottom)]);
		uvCrop = new Rectangle(0, 0, 1, 1);		// default crop rectangle
		
		// ----- create image snapshot
		bmd = new BitmapData(b.width, b.height, true, 0);
		var s:Sprite = new Sprite();
		img.drawOn(s);
		bmd.draw(s, new Matrix(1, 0, 0, 1, -b.left, -b.top));
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	private function getChildImageBounds():Rectangle
	{
		// ----- init corners as a square
		var minX:Number = Number.MAX_VALUE;
		var minY:Number = Number.MAX_VALUE;
		var maxX:Number = Number.MIN_VALUE;
		var maxY:Number = Number.MIN_VALUE;
		for (var j:int = image.Corners.length - 1; j > -1; j--)
		{
			if (minX > image.Corners[j].x)	minX = image.Corners[j].x;
			if (minY > image.Corners[j].y)	minY = image.Corners[j].y;
			if (maxX < image.Corners[j].x)	maxX = image.Corners[j].x;
			if (maxY < image.Corners[j].y)	maxY = image.Corners[j].y;
		}
		return new Rectangle(minX,minY,maxX-minX,maxY-minY);
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	override public function drawOn(s:Sprite):void
	{
		drawBmdWithin(bmd, s, Corners[0], Corners[1], Corners[2], Corners[3], 10, uvCrop);
	}//endfunction
	
	//=============================================================================
	// shows the cropping UI
	//=============================================================================
	public function doCropUI(s:Sprite,callBack:Function=null):void
	{
		var tl:Sprite = new IcoImageCorner();
		var br:Sprite = new IcoImageCorner();
		tl.x = 0;
		tl.y = 0;
		br.x = 1000;
		br.y = 1000;
		
		var disp:Sprite = new Sprite();
		disp.addChild(tl);
		disp.addChild(br);
		
		var ib:Rectangle = getChildImageBounds();
		
		var dragging:Sprite = null;
		function enterFrmaeHandler(ev:Event):void
		{
			disp.graphics.clear();
			var sw:Number = s.stage.stageWidth;
			var sh:Number = s.stage.stageHeight;
			
			var lMarg:Number = (sw - bmd.width) / 2;
			var tMarg:Number = (sh - bmd.height) / 2;
			disp.graphics.beginBitmapFill(bmd, new Matrix(1, 0, 0, 1, lMarg, tMarg), false);
			disp.graphics.drawRect(lMarg, tMarg, bmd.width, bmd.height);
			
			// ----- draws black overlay
			disp.graphics.beginFill(0x000000, 0.8);
			disp.graphics.drawRect(0, 0, sw, sh);
			disp.graphics.endFill();
			
			if (tl.x<lMarg)	tl.x=lMarg;
			if (tl.y<tMarg)	tl.y=tMarg;
			if (br.x>sw - lMarg)	br.x = sw - lMarg;
			if (br.y>sh - tMarg)	br.y = sh - tMarg;
			if (tl.x > br.x - 10)	
			{
				if (dragging==tl)	tl.x=br.x-10;	
				else 				br.x=tl.x+10;
			}
			if (tl.y > br.y - 10)	
			{
				if (dragging==tl)	tl.y=br.y-10;
				else				br.y=tl.y+10;
			}
			
			// ----- set cropping according to top left bottom right
			uvCrop.x = (tl.x-lMarg)/bmd.width;
			uvCrop.y = (tl.y-tMarg)/bmd.height;
			uvCrop.width = (br.x - tl.x)/bmd.width;
			uvCrop.height = (br.y - tl.y)/bmd.height;
			
			// ----- set drawn image on canvas to reflect rect crop
			Corners = Vector.<Point>([	new Point(ib.left+ib.width*uvCrop.left,	ib.top+ib.height*uvCrop.top),
										new Point(ib.left+ib.width*uvCrop.right,ib.top+ib.height*uvCrop.top),
										new Point(ib.left+ib.width*uvCrop.right,ib.top+ib.height*uvCrop.bottom),
										new Point(ib.left+ib.width*uvCrop.left,	ib.top+ib.height*uvCrop.bottom)]);
			
			// ----- draws crop area
			disp.graphics.beginBitmapFill(bmd, new Matrix(1, 0, 0, 1, lMarg, tMarg), false);
			disp.graphics.drawRect(tl.x, tl.y, br.x-tl.x, br.y-tl.y);
		}//endfunction
		
		function mouseDownHandler(ev:Event):void
		{
			if (tl.hitTestPoint(s.stage.mouseX, s.stage.mouseY))
			{dragging = tl;	tl.startDrag();}
			if (br.hitTestPoint(s.stage.mouseX, s.stage.mouseY))
			{dragging = br;	br.startDrag();}
		}
		
		function mouseUpHandler(ev:Event):void
		{
			tl.stopDrag();
			br.stopDrag();
		}
		disp.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		disp.addEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
		disp.addEventListener(Event.ENTER_FRAME, enterFrmaeHandler);
		
		var btn:Sprite = PPTool.utils.createTextButton("OK",function():void 
		{
			disp.parent.removeChild(disp);
			disp.removeEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
			disp.removeEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
			disp.removeEventListener(Event.ENTER_FRAME, enterFrmaeHandler);	
			if (callBack!=null) callBack();
		});
		
		btn.x = (s.stage.stageWidth-btn.width)/2;
		btn.y = s.stage.stageHeight - btn.height*2;
		disp.addChild(btn);
		s.stage.addChild(disp);
	}//endfunction
}//endclass

class GroupImage extends Image
{
	public var Images:Vector.<Image> = null;
	public var CornerRatios:Vector.<Vector.<Point>> = null;	// express subImage corners as ratios of corners
	
	//=============================================================================
	// 
	//=============================================================================
	public function GroupImage(I:Vector.<Image>):void
	{
		id = "...";		// no id!
		url = "...";	// no url!
		
		updateImages(I);
	}//endconstr
	
	//=============================================================================
	// 
	//=============================================================================
	public function addImage(img:Image):void
	{
		Images.push(img);
		updateImages(Images);
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	private function updateImages(I:Vector.<Image>):void
	{
		Images = I;
		
		// ----- ratios used to calculate the 4 corner positions of child images
		CornerRatios = new Vector.<Vector.<Point>>();
		var r:Rectangle = boundingRect();	// bounding rects of given images
		Corners = Vector.<Point>([	new Point(r.left,r.top),
									new Point(r.right,r.top),
									new Point(r.right,r.bottom),
									new Point(r.left,r.bottom)]);
		for (var i:int=Images.length-1; i>-1; i--)
		{
			var C:Vector.<Point> = Images[i].Corners;
			var Ratios:Vector.<Point> = new Vector.<Point>();
			for (var j:int=C.length-1; j>-1; j--)
			{
				var rat:Point = new Point((C[j].x-r.x)/r.width,(C[j].y-r.y)/r.height);
				Ratios.unshift(rat);
			}//endfor
			CornerRatios.unshift(Ratios);
		}
		
		updateBranch();		// composite of child Images
	}//endfunction
	
	//=============================================================================
	// 
	//=============================================================================
	override public function updateBranch():void
	{
		// ----- adjust children corners according to self corners
		var C0:Point = Corners[0];
		var C1:Point = Corners[1];
		var C2:Point = Corners[2];
		var C3:Point = Corners[3];
		for (var i:int=Images.length-1; i>-1; i--)
		{
			var Ratio:Vector.<Point> = CornerRatios[i];
			var img:Image = Images[i];
			for (var j:int=img.Corners.length-1; j>-1; j--)
			{
				var r:Point = Ratio[j];
				img.Corners[j].x = (C0.x*(1-r.x)+C1.x*r.x)*(1-r.y) + (C3.x*(1-r.x)+C2.x*r.x)*r.y;
				img.Corners[j].y = (C0.y*(1-r.x)+C1.y*r.x)*(1-r.y) + (C3.y*(1-r.x)+C2.y*r.x)*r.y;
			}
			if (img is GroupImage) (GroupImage)(img).updateBranch();
		}
	}//endfunction
	
	//=============================================================================
	// bounding rect for all images within this group
	//=============================================================================
	public function boundingRect():Rectangle
	{
		var minX:Number = Number.MAX_VALUE;
		var minY:Number = Number.MAX_VALUE;
		var maxX:Number = Number.MIN_VALUE;
		var maxY:Number = Number.MIN_VALUE;
		for (var i:int = Images.length - 1; i > -1; i--)
		{
			var img:Image = Images[i];
			for (var j:int = img.Corners.length - 1; j > -1; j--)
			{
				if (minX > img.Corners[j].x)	minX = img.Corners[j].x;
				if (minY > img.Corners[j].y)	minY = img.Corners[j].y;
				if (maxX < img.Corners[j].x)	maxX = img.Corners[j].x;
				if (maxY < img.Corners[j].y)	maxY = img.Corners[j].y;
			}
		}//endfor
		return new Rectangle(minX,minY,maxX-minX,maxY-minY);
	}//endfunction
	
	//=============================================================================
	// draws all children of self
	//=============================================================================
	override public function drawOn(s:Sprite):void
	{	
		// ----- draw composite image on temp sprite
		for (var i:int = 0; i < Images.length; i++)
			Images[i].drawOn(s);
	}//endfunction
	
	//=============================================================================
	// gets the center of multiple images 
	//=============================================================================
	override public function getCenter():Point
	{
		var r:Rectangle = boundingRect();
		return new Point(r.x + r.width / 2, r.y + r.height / 2);
	}//endfunction
	
	//=============================================================================
	// shift so that center of corner points is at x,y
	//=============================================================================
	override public function centerTo(x:Number,y:Number):void
	{
		trace("GroupImage.CenterTo("+x+","+y+")");
		super.centerTo(x,y);
		updateBranch();
	}//endfunction
	
	//=============================================================================
	// rotate around center by ang radians 
	//=============================================================================
	override public function rotate(ang:Number):void
	{
		trace("GroupImage.rotate("+ang+")");
		super.rotate(ang);
		updateBranch();
	}//endfunction
	
	//=============================================================================
	// uniform scale around center by sc 
	//=============================================================================
	override public function scale(sc:Number):void
	{
		trace("GroupImage.scale("+sc+")");
		super.scale(sc);
		updateBranch();
	}//endfunction
}//endclass

class FloatingMenu extends Sprite		// to be extended
{
	protected var Btns:Vector.<Sprite> = null;
	protected var callBackFn:Function = null;
	protected var overlay:Sprite = null;			// something on top to disable this
	protected var mouseDownPt:Point = null;
	public var draggable:Boolean = true;
	
	//===============================================================================================
	// simpleton constructor, subclasses must initialize Btns and callBackFn
	//===============================================================================================
	public function FloatingMenu():void
	{
		filters = [new DropShadowFilter(4,90,0x000000,1,4,4,0.5)];
		addEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		addEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		addEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		addEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onMouseDown(ev:Event):void
	{
		if (stage==null) return;
		mouseDownPt = new Point(this.mouseX,this.mouseY);
		if (draggable) this.startDrag();
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onMouseUp(ev:Event):void
	{
		if (stage==null) return;
		this.stopDrag();
		if (overlay!=null) return;
		if (mouseDownPt==null)	return;	// mousedown somewhere else
		if (mouseDownPt.subtract(new Point(this.mouseX,this.mouseY)).length>10) return;
		mouseDownPt = null;
		if (Btns!=null)
		for (var i:int=Btns.length-1; i>-1; i--)
			if (Btns[i].parent==this && Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				if  (callBackFn!=null) callBackFn(i);	// exec callback function
				return;
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onEnterFrame(ev:Event):void
	{
		if (overlay!=null && overlay.parent!=this) overlay=null;
		if (stage==null) return;
		
		var A:Array = null;
		
		if (Btns!=null)
		for (var i:int=Btns.length-1; i>-1; i--)
			if (overlay==null && Btns[i].hitTestPoint(stage.mouseX,stage.mouseY))
			{
				A = Btns[i].filters;
				if (A.length==0)
					Btns[i].filters=[new GlowFilter(0x000000,1,4,4,1)];
				else if ((GlowFilter)(A[0]).strength<1)
					(GlowFilter)(A[0]).strength+=0.1;
			}
			else
			{
				if (Btns[i].filters.length>0)
				{
					A = Btns[i].filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=0.1;
					else 
						A = null;
					Btns[i].filters = A;
				}
			}
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	protected function onRemove(ev:Event):void
	{
		removeEventListener(MouseEvent.MOUSE_DOWN,onMouseDown);
		removeEventListener(MouseEvent.MOUSE_UP,onMouseUp);
		removeEventListener(Event.REMOVED_FROM_STAGE,onRemove);
		removeEventListener(Event.ENTER_FRAME,onEnterFrame);
	}//endfunction
	
	//===============================================================================================
	// draws a striped rectangle in given sprite 
	//===============================================================================================
	public static function drawStripedRect(s:Sprite,x:Number,y:Number,w:Number,h:Number,c1:uint,c2:uint,rnd:uint=10,sw:Number=5,rot:Number=Math.PI/4) : Sprite
	{
		if (s==null)	s = new Sprite();
		var mat:Matrix = new Matrix();
		mat.createGradientBox(sw,sw,rot,0,0);
		s.graphics.beginGradientFill("linear",[c1,c2],[1,1],[127,128],mat,"repeat");
		s.graphics.drawRoundRect(x,y,w,h,rnd,rnd);
		s.graphics.endFill();
		
		return s;
	}//endfunction 
}//endclass

class IconsMenu extends FloatingMenu	
{
	private var pageIdx:int=0;
	private var pageBtns:Sprite = null;
	private var r:int = 1;		// rows
	private var c:int = 1;		// cols
	private var bw:int = 150;	// btn width
	private var bh:int = 50;	// btn height
	private var marg:int = 10;
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function IconsMenu(Icos:Vector.<Sprite>,rows:int,cols:int,callBack:Function):void
	{
		Btns = Icos;
		callBackFn = callBack;
	
		if (rows<1)	rows = 1;
		if (cols<1) cols = 1;
		r = rows;
		c = cols;
		pageBtns = new Sprite();
		addChild(pageBtns);
		
		refresh();
		
		function pageBtnsClickHandler(ev:Event) : void
		{
			for (var i:int=pageBtns.numChildren-1; i>-1; i--)
				if (pageBtns.getChildAt(i).hitTestPoint(stage.mouseX,stage.mouseY))
					pageTo(i);
		}
		function pageBtnsRemoveHandler(ev:Event) : void
		{
			pageBtns.removeEventListener(MouseEvent.CLICK,pageBtnsClickHandler);
			pageBtns.removeEventListener(Event.REMOVED_FROM_STAGE,pageBtnsRemoveHandler);
		}
		
		pageBtns.addEventListener(MouseEvent.CLICK,pageBtnsClickHandler);
		pageBtns.addEventListener(Event.REMOVED_FROM_STAGE,pageBtnsRemoveHandler);
	}//endfunction
	
	//===============================================================================================
	// 
	//===============================================================================================
	public function refresh():void
	{
		var tw:int=0;
		var th:int=0;
		for (var i:int=Btns.length-1; i>-1; i--)
		{
			tw+=Btns[i].width;
			th+=Btns[i].height;
		}
		if (tw>0)	bw = tw/Btns.length;	// find btn width 
		if (th>0)	bh = th/Btns.length;	// find btn height
		
		// ----- update pageBtns to show correct pages
		var pageCnt:int = Math.ceil(Btns.length/(r*c));
		while (pageBtns.numChildren>pageCnt)	
			pageBtns.removeChildAt(pageBtns.numChildren-1);
		for (i=pageBtns.numChildren; i<pageCnt; i++)
		{
			var sqr:Sprite = new Sprite();
			sqr.graphics.beginFill(0x666666,1);
			sqr.graphics.drawRect(0,0,9,9);
			sqr.graphics.endFill();
			sqr.x = i*(sqr.width+10);
			sqr.buttonMode = true;
			pageBtns.addChild(sqr);
		}
		
		if (pageCnt>1)
		{
			pageBtns.visible=true;
			drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3+marg*2,0xFFFFFF,0xF6F6F6,20,10);
		}
		else
		{
			pageBtns.visible=false;
			drawStripedRect(this,0,0,(bw+marg)*c+marg*3,(bh+marg)*r+marg*3,0xFFFFFF,0xF6F6F6,20,10);
		}
		pageBtns.x = (this.width-pageBtns.width)/2;
		pageBtns.y =this.height-marg*2-pageBtns.height/2;
		
		pageTo(pageIdx);
	}//endfunction
	
	//===============================================================================================
	// go to page number
	//===============================================================================================
	public function pageTo(idx:int):void
	{
		while (numChildren>1)	removeChildAt(1);	// child 0 is pageBtns
		
		if (idx<0)	idx = 0;
		if (idx>Math.ceil(Btns.length/(r*c)))	idx = Math.ceil(Btns.length/(r*c));
		var a:int = idx*r*c;
		var b:int = Math.min(Btns.length,a+r*c);
		for (var i:int=a; i<b; i++)
		{
			var btn:Sprite = Btns[i];
			btn.x = marg*2+(i%c)*(bw+marg)+(bw-btn.width)/2;
			btn.y = marg*2+int((i-a)/c)*(bh+marg)+(bh-btn.height)/2;
			addChild(btn);
		}
		
		for (i=pageBtns.numChildren-1; i>-1; i--)
		{
			if (i==idx)
				pageBtns.getChildAt(i).transform.colorTransform = new ColorTransform(1,1,1,1,70,70,70);
			else
				pageBtns.getChildAt(i).transform.colorTransform = new ColorTransform();
		}
		pageIdx = idx;
	}//endfunction	
}//endclass