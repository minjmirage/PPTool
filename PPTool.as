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
	import mx.utils.Base64Encoder;
	import mx.utils.Base64Decoder;
	
	import com.greensock.TweenLite;
	
	[SWF(width = "800", height = "600", frameRate = "30")];
			
	public class PPTool extends Sprite
	{
		public static var baseUrl:String = "http://ruanzhuangyun.cn/";// "http://symspace.e360.cn/";
		
		public var userId:int = 0;
		public var userToken:String = null;
		public var properties:ProjProperties = null;
		
		public var main:MovieClip = null;
		
		public static var utils:MenuUtils = null;
		private var LHS:LHSMenu = null;
		private var RHS:RHSMenu = null;
		private var sliderBar:Sprite = null;
		private var propMenu:Sprite = null;			// floating properties menu
		
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
		private var grid:Sprite = null;				// the grid lines layer
		private var paper:Sprite = null;			// the thingy below the canvas
		
		private var disableClick:int = 0;	// prevents clicking on stuff behind popup if >0
		
		private var keyShift:Boolean = false;
		private var keyControl:Boolean = false;
		
		private var btnEditCombo:Sprite = null;		// edit button fot the combo pic
		
		//=============================================================================
		// 
		//=============================================================================
		public function PPTool():void
		{
			var ppp:Sprite = this;
			function addedToStageChk(ev:Event):void
			{
				if (stage == null) return;
				ppp.removeEventListener(Event.ENTER_FRAME, addedToStageChk);
				init();
			}
			ppp.addEventListener(Event.ENTER_FRAME, addedToStageChk);
		}//endconstr
		
		//=============================================================================
		// 
		//=============================================================================
		public function init() : void
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
			paper.filters = [new DropShadowFilter(2,45,0x000000)];
			addChild(paper);
			
			// -----
			grid = new Sprite();
			addChild(grid);
			updatePaper("4:3");
			
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
			
			btnEditCombo = new Sprite();
			btnEditCombo.addChild(new BtnEditCombo());
			btnEditCombo.addChild(new IcoRefresh());
			btnEditCombo.getChildAt(1).x = btnEditCombo.getChildAt(0).width + 5;
			btnEditCombo.getChildAt(1).y = (btnEditCombo.getChildAt(0).height -btnEditCombo.getChildAt(1).height)/2;
			btnEditCombo.getChildAt(1).filters = [new GlowFilter(0xAAAAAA,1,3,3,10)];
			btnEditCombo.buttonMode = true;
			utils = new MenuUtils(stage);	// init convenience utils 
			
			LHS = new LHSMenu();
			LHS.canvas.y = main.L.t.height;
			addChild(LHS.canvas);
			properties = LHS.projProperties;
			LHS.changeNotify = function():void
			{	// store undo state on change
				var s:String = getCurState();
				if (undoStk[undoStk.length-1]!=s) 
				{
					trace("push curState="+s);
					undoStk.push(s);
				}
			}//endfunction
			
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
			var csr:MovieClip = new CursorSymbols();
			var cb:Rectangle = csr.getBounds(csr);
			csr.graphics.beginFill(0x000000, 0);
			csr.graphics.drawRect(cb.left, cb.top, cb.width, cb.height);
			csr.graphics.endFill();
			picResizeUI.addChild(csr);
			(MovieClip)(picResizeUI.getChildAt(picResizeUI.numChildren - 1)).gotoAndStop(1);
			
			picResizeUI.buttonMode = true;
			picResizeUI.filters = [new GlowFilter(0x001133, 1, 2,2, 1)];
			
			// ----- create magnification slider -------------------
			sliderBar = createHSlider(function(sc:Number):void 
			{
				sc = (0.5*(sc)+1.5*(1-sc));
				canvas.scaleX = canvas.scaleY = sc;
				paper.scaleX = paper.scaleY = sc;
				grid.scaleX = grid.scaleY = sc;
			},103);
			sliderBar.x = 36;
			sliderBar.y = 16;
			main.B.l.addChild(sliderBar);
			
			if (root.loaderInfo.parameters.httpURL!=null) baseUrl = root.loaderInfo.parameters.httpURL+"";	
			if (root.loaderInfo.parameters.token!=null) userToken = root.loaderInfo.parameters.token+"";
			
			if (parent is Preloader && (Preloader)(parent).baseUrl != null)		{baseUrl = (Preloader)(parent).baseUrl;	trace("parent.baseUrl="+baseUrl); }
			if (parent is Preloader && (Preloader)(parent).userToken != null) 	{userToken = (Preloader)(parent).userToken;	trace("parent.token="+userToken); }
			if (baseUrl.charAt(baseUrl.length - 1) != "/")	baseUrl += "/";
			
			//addChild(utils.createText("baseUrl="+baseUrl+"  userToken="+userToken));
			
			// ----- function to exec after got userToken
			var pptool:PPTool = this;
			function initAfterLogin():void
			{
				// ----- load a save proj if given id -----------------
				if (parent is Preloader && (Preloader)(parent).id != null)
				{
					function onComplete(ev:Event):void
					{
						var projects:Array = JSON.parse(ldr.data).projects;
						for (var i:int = projects.length - 1; i > -1; i--)
							if (projects[i].id + "" == (Preloader)(parent).id + "")
							{
								restoreFromData(projects[i].data);
								return;
							}
					}//endfunction
					var ldr:URLLoader = new URLLoader();
					ldr.addEventListener(Event.COMPLETE, onComplete);
					ldr.load(new URLRequest(baseUrl + "?n=api&a=scheme&c=scheme&m=index&token=" + userToken));
					trace("here???");
				}//endif
			
				// ----- the RHS menu -------------------------------
				RHS = new RHSMenu(userToken,getProductItemsData);
				addChild(RHS.canvas);	// above canvas and paper
				prevW = 0;
				RHS.pptool = pptool;
				RHS.clickCallBack = function (img:Image):void 
				{
					trace("RHS.clickCallBack");
					target = img;
					img.centerTo(canvas.mouseX,canvas.mouseY);
					addImage(img);
					mouseMoveFn = function():void 	// start drag
					{
						img.centerTo(canvas.mouseX,canvas.mouseY);
					}
					mouseUpFn = function():void
					{
						mouseUpFn = null;
						if (paper.hitTestPoint(stage.mouseX,stage.mouseY)==false)
						{
							trace("removed image not on paper");
							if (LHS.selected.Pics.indexOf(img)!=-1)
								LHS.selected.Pics.splice(LHS.selected.Pics.indexOf(img),1);
						}
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
		private function updatePaper(ratio:String=null):void
		{
			var b:Rectangle = paper.getBounds(paper);
			if (ratio=="4:3")		b = new Rectangle(-1024/2,-768/2,1024,768);	// 4:3 ratio
			else if (ratio=="16:9")	b = new Rectangle(-1280/2,-720/2,1280,720);	// 16:9 ratio
			
			paper.graphics.clear();
			paper.graphics.beginFill(0xFFFFFF,1);
			paper.graphics.drawRect(b.left,b.top,b.width,b.height);
			paper.graphics.endFill();
			
			// ----- draw grid lines
			grid.graphics.clear();
			grid.graphics.lineStyle(0,0x000000,0.05);
			var n:int = b.width/50;
			var off:Number = (b.width-n*50)/2;
			for (var i:int=n; i>=0; i--)
			{
				grid.graphics.moveTo(b.left+i*50+off,b.top);
				grid.graphics.lineTo(b.left+i*50+off,b.bottom);
			}
			n = b.height/50;
			off = (b.height-n*50)/2;
			for (var i:int=n; i>=0; i--)
			{
				grid.graphics.moveTo(b.left,b.top+i*50+off);
				grid.graphics.lineTo(b.right,b.top+i*50+off);
			}
			grid.graphics.lineStyle();
			
			// ----- draw bitmap onto paper if background specified
			if (LHS==null) return;
			var page:Page = LHS.selected;
			if (page.bg != null)
			{
				var pSc:Number = Math.min(b.width / page.bg.width, b.height / page.bg.height);
				paper.graphics.beginBitmapFill(page.bg, new Matrix(pSc, 0, 0, pSc, -(page.bg.width * pSc)/2, -(page.bg.height * pSc)/2));
				paper.graphics.drawRect(-page.bg.width*pSc/2, -page.bg.height*pSc/2, page.bg.width*pSc, page.bg.height*pSc);
				paper.graphics.endFill();
			}
		}//endfunction
		
		//=============================================================================
		// grey out and disables click interractions, returns remove disable function
		//=============================================================================
		private function disableInterractions(alp:Number=0.8):Function
		{
			trace("disableInterractions("+alp+")");
			if (disableClick < 0)	disableClick = 0;
			disableClick++;
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
				disableClick--;
				trace("enableClick!");
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
			var bmp:Bitmap = new Bitmap(new BitmapData(s.msk2.width-2,s.msk2.height,false,0xFFFFFF));
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
					s.b2.hitTestPoint(mx,my))
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
			
			s.tf.text = "方案名 : "+properties.name+
						"\n风格 : "+properties.style.split("1")[1]+
						"   类型 : "+properties.type.split("|")[1]+
						"\n最后编辑时间 : "+properties.lastModify;
			setGeneralBtn(s.b1,"确定");
			setGeneralBtn(s.b2,"关闭");
			setGeneralBtn(s.bRev,"反选");
			setGeneralBtn(s.bAll,"全选");
			
			addChild(s);
			return s;
		}//endfunction
		
		//=============================================================================
		// shows the list of products in this project
		//=============================================================================
		private function showItemsList(callBack:Function=null):Sprite
		{
			if (properties.saveId=="")
			{
				return null;   
			}
			
			var enableI:Function = disableInterractions();
			
			function createBtn(txt:String):Sprite
			{
				var s:Sprite = new Sprite();
				var tf:TextField = utils.createText(txt);
				tf.mouseEnabled = false;
				tf.x = 5;
				tf.y = 5;
				s.addChild(tf);
				LHSMenu.drawStripedRect(s,0,0,s.width+10,s.height+10,0xCCCCCC,0xC6C6C6,5,0);
				return s;
			}//endfunction
			
			function createTab(txt:String):Sprite
			{
				var s:Sprite = new Tab();
				var tf:TextField = utils.createText(txt);
				s.getChildAt(1).width = tf.width;
				s.getChildAt(2).x = s.getChildAt(1).x + s.getChildAt(1).width;
				tf.mouseEnabled = false;
				tf.x = s.getChildAt(0).width;
				tf.y = (s.height-tf.height)/2;
				s.addChild(tf);
				return s;
			}//endfunction
			
			// ----- creates the top labels -------------------------
			var ItmLst:Sprite = new PageList();	// this is the main sprite
			var labSpr:Sprite = new Sprite();
			labSpr.graphics.lineStyle(0, 0x333333, 0);
			labSpr.graphics.drawRect(0, 0, 810, 32);
			labSpr.x = 20;
			labSpr.y = 96;
			ItmLst.addChild(labSpr);
			
			var con:Sprite = new Sprite();	// container for item sprs
			con.x = labSpr.x;
			con.y = labSpr.y+labSpr.height;
			
			var marg:int = 10;
			
			// ------ create msk and scroll bar -------------------------------
			var msk:Sprite = new Sprite();
			msk.graphics.beginFill(0,1);
			msk.graphics.drawRect(0,0,labSpr.width+80,350);
			msk.graphics.endFill();
			msk.x = labSpr.x;
			msk.y = labSpr.y+labSpr.height;
			con.mask = msk;
			ItmLst.addChild(msk);
			
			var scrol:Sprite = new Sprite();
			LHSMenu.drawStripedRect(scrol,0,0,marg/2,msk.height+labSpr.height,0xAAAAAA,0xACACAC,5,10);
			scrol.x = labSpr.x+labSpr.width+10;
			scrol.y = labSpr.y;
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
			
			// ----- make scrollbar mouseWheel scrollable
			function mouseWheelHandler(ev:MouseEvent):void
			{
				bar.y -= ev.delta*5;
				if (bar.y < 0) bar.y = 0;
				if (bar.y > msk.height+labSpr.height - bar.height) bar.y = msk.height+labSpr.height - bar.height;
			}//endfunction
			ItmLst.addEventListener(MouseEvent.MOUSE_WHEEL,mouseWheelHandler);
			
			var totalTf:TextField = utils.createText("总计金额： －－ 元， 产品件数：－－件");
			totalTf.x = marg;
			totalTf.y = msk.y+msk.height+20;
			ItmLst.addChild(totalTf);
			
			// ----- changes to given items P ---------------------------------
			function setDisplayList(P:Array):void
			{
				var spacs:Array = [20,60,150,210,280,370,460,530,600,660,750];
				
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
					var imgUrl:String = baseUrl + "thumb.php?src=" + P[i].pic + "&w=50";
					trace("imgUrl="+imgUrl);
					var dat:Array = [i,utils.createThumbnail(imgUrl),P[i].productname,P[i].productsn,P[i].pinglei,P[i].size,P[i].material,P[i].color,P[i].price,P[i].count,P[i].price];
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
							I[i][j].x = Number(spacs[j])  - tf.width / 2;
							s.addChild(I[i][j]);
						}
						else
						{
							var tf:TextField = utils.createText(I[i][j],-1,11,0x999999);
							tf.x = Number(spacs[j]) - tf.width / 2;
							s.addChild(tf);
						}
					}
					for (j=0; j<s.numChildren; j++)	s.getChildAt(j).y = (s.height-s.getChildAt(j).height)/2;	// center align the elems
					
					if (s.numChildren<3)	
						yOff+= 10;
					else
					{
						s.graphics.lineStyle(0,0x999999);
						s.graphics.drawRect(0,0,labSpr.width,s.height);
					}
					s.y = yOff;
					yOff+= s.height;
					con.addChild(s);
				}
				
				totalTf.htmlText = "<font size='15' >总计金额：<font size='17' color='#33AAAA' >"+totalCost+"</font> 元， 产品件数：<font size='17' color='#33AAAA' >"+P.length+"</font> 件</font>";
				
				bar.graphics.clear();
				LHSMenu.drawStripedRect(bar,0,0,scrol.width,Math.min(scrol.height,msk.height/con.height*scrol.height),0x333355,0x373757,5,10);
			}//endfunction
						
			// ----- update on changes ----------------------------------------
			function updateHandler(ev:Event):void
			{
				con.y = msk.y-(con.height+100)*bar.y/scrol.height;
			}//endfunction
			ItmLst.addEventListener(Event.ENTER_FRAME,updateHandler);
			
			ItmLst.x = (stage.stageWidth-ItmLst.width)/2;
			ItmLst.y = (stage.stageHeight-ItmLst.height)/2;
			ItmLst.addChild(con);
			//pageSelector.y = -pageSelector.height-5;
			//ItmLst.addChild(pageSelector);
			
			// ------ to close when clicked outside 
			addChild(ItmLst);
			
			function clickHandler(ev:Event):void
			{
				if (ItmLst.hitTestPoint(stage.mouseX, stage.mouseY))	return;
				ItmLst.removeEventListener(Event.ENTER_FRAME,updateHandler);
				bar.removeEventListener(MouseEvent.MOUSE_DOWN,startDragHandler);
				stage.removeEventListener(MouseEvent.MOUSE_UP,stopDragHandler);
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, clickHandler);
				ItmLst.removeEventListener(MouseEvent.MOUSE_WHEEL,mouseWheelHandler);
				ItmLst.parent.removeChild(ItmLst);
				enableI();
				if (callBack!=null) callBack();
			}
			stage.addEventListener(MouseEvent.MOUSE_DOWN,clickHandler);
			
			
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=info&id="+properties.saveId+"&token="+userToken);
			ldr.load(req);
			
			// ----- select space to show -------------------------------------
			function createSpaceSelector(spaceObjs:Array,AllProds:Array):Sprite
			{
				var s:Sprite = new Sprite();
				for (var i:int=0; i<spaceObjs.length; i++)
				{
					//printProp(spaceObjs[i]);
					var btn:Sprite = createTab(spaceObjs[i].spacename);
					btn.x = s.width+5;
					s.addChild(btn);
				}
				
				// ----------
				var cartBtn:GeneralBtn = new GeneralBtn();
				setGeneralBtn(cartBtn, "加入购物车");
				cartBtn.x = labSpr.width - cartBtn.width;
				cartBtn.y -= 5;
				s.addChild(cartBtn);
				var dlBtn:GeneralBtn = new GeneralBtn();
				setGeneralBtn(dlBtn,"下载");
				dlBtn.x = labSpr.width-cartBtn.width-dlBtn.width-5;
				dlBtn.y -= 5;
				s.addChild(dlBtn);
				
				function clickSelHandler(ev:Event):void
				{
					var Ids:Array = [];
					for (var i:int=0; i<spaceObjs.length; i++)
					{
						var btn:Sprite = s.getChildAt(i) as Sprite;
						var isSel:Boolean = true;
						if (btn.hitTestPoint(stage.mouseX,stage.mouseY))
						{
							for (var j:int=0; j<3; j++)
								if ((MovieClip)(btn.getChildAt(j)).currentFrame==1)	
								{	(MovieClip)(btn.getChildAt(j)).gotoAndStop(2); isSel = false;}
								else
									(MovieClip)(btn.getChildAt(j)).gotoAndStop(1);
						}
						if (isSel) Ids.push(spaceObjs[i].spaceId);
					}
					
					var SelProds:Array = [];
					for (i=0; i<AllProds.length; i++)
						if (Ids.indexOf(AllProds[i].spaceId)>-1)
							SelProds.push(AllProds[i]);
					
					setDisplayList(SelProds);
					
					if (dlBtn.hitTestPoint(stage.mouseX,stage.mouseY))
					{
						navigateToURL(new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=excel&id="+properties.saveId+"&token="+userToken));
					}
					else if (cartBtn.hitTestPoint(stage.mouseX,stage.mouseY))
					{
						var jsonStr:String = "";
						for (i = 0; i < SelProds.length; i++)
							jsonStr += JSON.stringify( { productid:SelProds[i].id , goodsid:1, productsn:SelProds[i].productsn , total:SelProds[i].count } )+",";
						if (jsonStr.length>1) jsonStr = jsonStr.slice(0, jsonStr.length - 1);
						var ldr:URLLoader = new URLLoader();
						var req:URLRequest = new URLRequest(baseUrl + "?n=api&a=user&c=cart&m=add&json=[" + jsonStr + "]&token=" + userToken);
						req.method = "post";  
						var vars:URLVariables = new URLVariables();  
						vars.json = "["+jsonStr+"]";  
						req.data = vars;
						ldr.load(req);
						trace("url:"+ baseUrl + "?n=api&a=user&c=cart&m=add&json=[" + jsonStr + "]&token=" + userToken );
						
						function onComplete(e:Event):void
						{
							trace("cartBtn response : "+ldr.data);
							var o:Object = JSON.parse(ldr.data);
							var notify:Sprite = utils.createChoices("购物车添加成功", 
																	Vector.<String>(["确认"]), 
																	Vector.<Function>([function():void { ItmLst.visible = true; notify.parent.removeChild(notify); } ]),
																	120);
							notify.x = (stage.stageWidth - notify.width) / 2;
							notify.y = (stage.stageHeight - notify.height) / 2;
							ItmLst.parent.addChild(notify);
							ItmLst.visible = false;
						}
						ldr.addEventListener(Event.COMPLETE, onComplete);  
					}
				}//endfunction
				s.addEventListener(MouseEvent.CLICK,clickSelHandler);
				
				function cleanUpHandler(ev:Event):void
				{
					s.removeEventListener(MouseEvent.CLICK,clickSelHandler);
					s.removeEventListener(Event.REMOVED_FROM_STAGE,cleanUpHandler);
				}
				s.addEventListener(Event.REMOVED_FROM_STAGE,cleanUpHandler);
				
				s.x = labSpr.x;
				s.y = labSpr.y - s.height;
				ItmLst.addChild(s);
				
				return s;
			}//endfunction
			
			function printProp(o:Object):void
			{
				for(var id:String in o) 
					trace(id+" : " +o[id]);
			}//endfunction
			
			// ----- when server returns, execute -----------------------------
			function onLoaded():void
			{
				var o:Object = JSON.parse(ldr.data);
				if (o.scheme.qdjson == null)	return;
				
				o = JSON.parse(o.scheme.qdjson);
				trace("showItemsList data=" + prnObject(o));
				
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
							// add prod in or increase count
							var prod:Object = catData[prodId];
							for (var i:int = Products.length - 1; i > -1; i--)
								if (Products[i].productsn == prod.productsn)
								{
									Products[i].count++;
									break;
								}
							if (i==-1)	Products.push(prod);
						}
					}//endfor
				}//endfor
			
				// show the items
				setDisplayList(Products);
				
				// show the space slelection
				createSpaceSelector(Spaces,Products);
			}//endfunction
			ldr.addEventListener(Event.COMPLETE, onLoaded);  
			
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
			
			var lst:Sprite = utils.createDropDownList(Vector.<String>(["4:3","16:9"]),properties.form,function(t:String):void {nprop.form=t; updatePaper(t);}, 200);
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
				var A:Array = o.categories;
				var typ:Array = [];
				var sty:Array = [];
				while (A.length > 0 && A[0].classname != "类型")		// HACK!!!
					A.shift();			// to REMOVE all other nonsense....!!
				if (A.length > 0)	A.shift();
				while (A.length > 0 && A[0].classname != "色系")
					typ.push(A.shift());	// store sytle types
				while (A.length > 0 && A[0].classname != "风格")		// HACK!!!
					A.shift();			// to REMOVE all other nonsense....!!
				if (A.length > 0)	A.shift();
				while (A.length > 0 && A[0].classname != "空间")
					sty.push(A.shift());	// store sytle types
				
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
			setGeneralBtn(s.b1,"确定");
			setGeneralBtn(s.b2,"取消");
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
			function(t:String):void {nprop.form=t; updatePaper(t);}, 170);
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
				
				var A:Array = o.categories;
				var typ:Array = [];
				var sty:Array = [];
				while (A.length > 0 && A[0].classname != "类型")		// HACK!!!
					A.shift();			// to REMOVE all other nonsense....!!
				if (A.length > 0)	A.shift();
				while (A.length > 0 && A[0].classname != "色系")
					typ.push(A.shift());	// store sytle types
				while (A.length > 0 && A[0].classname != "风格")		// HACK!!!
					A.shift();			// to REMOVE all other nonsense....!!
				if (A.length > 0)	A.shift();
				while (A.length > 0 && A[0].classname != "空间")
					sty.push(A.shift());	// store sytle types
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
			setGeneralBtn(s.b1,"确定");
			setGeneralBtn(s.b2,"关闭");
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
																undoStk = [];
																redoStk = [];
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
																		saveToServer("incognito");
																	cleanUp();
																});
															},
															function():void			// save as new
															{
																showSaveProperties(function(saveIt:Boolean):void
																{
																	if (saveIt)
																	{
																		properties.saveId = "";		
																		saveToServer("incognito");
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
																						trace("share response: " + ldr.data);
																						properties.isPublic = true;
																					}//endfunction
																					ldr.addEventListener(Event.COMPLETE, onComplete);
																					ldr.load(new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=share&id="+properties.saveId+"&token="+userToken));
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
			
			if (properties.saveId == "")
			{
				labels.splice(3, 2);
				fns.splice(3, 2);
			}
			var s:Sprite = utils.createNoTitleChoices(labels,fns);
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
			
			s.filters = [new DropShadowFilter(1, 45, 0x000000, 1, 2,2)];
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
			utils.createNoTitleChoices(Vector.<String>(["设为页面背景图","设为空间背景图","设为全部背景图"]),
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
			s.filters = [new DropShadowFilter(1, 45, 0x000000, 1, 2,2)];
			addChild(s);
		}//endfunction
		
		//=============================================================================
		// show list of save files to load
		//=============================================================================
		public function showSaveFiles():void
		{
			var enableI:Function = disableInterractions();
			
			// --------------------------------------------------------------------
			function makeBtn(data:Object,isPublic:Boolean=false):Sprite
			{
				// ----- try load first thumbnail from base64
				var ico:Bitmap = new Bitmap(new BitmapData(74,74,false,0xFFFFFF),"auto",true);
				try {
					if (data.b64thumb != null)
					{
						var b64dec:Base64Decoder = new Base64Decoder();
						b64dec.decode(data.b64thumb);
						var ldr:Loader = new Loader();
						function imgLoaded(ev:Event):void	
						{
							ldr.contentLoaderInfo.removeEventListener(Event.COMPLETE, imgLoaded);
							ico.bitmapData = (Bitmap)(ldr.content).bitmapData;
							ico.width = ico.height = 74;
						}
						ldr.loadBytes(b64dec.toByteArray());
						ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, imgLoaded);
					}
				} 
				catch (e:Error)
				{
					trace("ERROR DECODING b64thumb!!");
				}
				
				var btn:MovieClip = new SaveBox();
				if (isPublic || data.properties.isPublic == true)	btn.gotoAndStop(2);
				else 												btn.gotoAndStop(1);
				ico.x = (btn.width-ico.width)/2+3;
				ico.y = (btn.height-ico.height)/2;
				btn.addChild(ico);
				var tf:TextField = 
				utils.createText("<font size='15'><b>" + data.properties.name + "</b></font>\n" +
								"<font size='11'>风格 ： " + data.properties.style.split("|").pop() + "    类型 ： " + data.properties.type.split("|").pop() + "\n" +
								"最后编辑日期 ： "+data.properties.lastModify+"</font>");
				tf.y = (btn.height-tf.height)/2;
				tf.x = 30;
				btn.addChild(tf);
				btn.mouseChildren = false;
				
				// ----- load product thumbnails
				var tA:Vector.<String> = new Vector.<String>();
				for (var i:int=0; i<data.Pages.length; i++)
					for (var j:int=0; j<data.Pages[i].Pics.length; j++)
					{
						var po:Object = data.Pages[i].Pics[j];
						if (po.data != null && po.pic != null)	// is a combo pic
							tA.push(po.pic);
					}
				trace("** proj:"+data.properties.name+"  thumbs to load="+tA);
					
				var cnt:int = 0;
				function loadNextThumb():void
				{
					if (cnt<3 && cnt<tA.length)
					{
						MenuUtils.loadAsset(baseUrl + "thumb.php?src="+tA[cnt]+"&w=74", function(tmb:Bitmap):void 
						{
							trace("proj:" + data.properties.name + "  thumb"+cnt+":" + tA[cnt] + "  loaded.");
							tf.appendText(cnt + "");
							tmb.y = (btn.height - tmb.height) / 2;
							tmb.x = ico.x + (cnt + 1) * 83;
							btn.addChild(tmb);
							cnt++;
							loadNextThumb();
						});
					}
				}//endfunction
				if (tA.length > 0)	loadNextThumb();
				
				return btn;
			}//endfunction
			
			// --------------------------------------------------------------------
			function createMenu(projects:Array,Btns:Vector.<Sprite>):void
			{
				var men:Sprite = new PageOpen();
				var con:Sprite = new Sprite();
				con.buttonMode = true;
				con.x = 15;
				con.y = 50;
				men.addChild(con);
				
				// ----- create page selectors
				var pageSel:Sprite = new Sprite();
				pageSel.buttonMode = true;
				pageSel.mouseChildren = false;
				
				function gotoPage(p:int = 0):void
				{
					var py:int = 0;
					while (con.numChildren > 0) con.removeChildAt(0);
					for (var i:int=Math.min(p*4, Btns.length); i<Math.min((p+1)*4,Btns.length); i++)
					{
						Btns[i].y = py;
						py += Btns[i].height+5;
						con.addChild(Btns[i]);
						Btns[i].alpha = 0;
						TweenLite.to(Btns[i], 0.5, {alpha:1, delay:py/1000});
					}
					
					while (pageSel.numChildren > 0) pageSel.removeChildAt(0);
					for (i=0; i<Btns.length/4; i++)
					{
						var tf:TextField = null;
						if (i==p)
						{
							tf = utils.createText((i + 1) + "", -1, 12, 0xFFFFFF);
							tf.background = true;
							tf.backgroundColor = 0x999999;
						}
						else
							tf = utils.createText((i + 1) + "", -1, 12, 0x999999);
						tf.x = i * 20;
						pageSel.addChild(tf);
					}
					pageSel.x = (men.width - pageSel.width) / 2;
					pageSel.y = men.height - pageSel.height - 30;
					men.addChild(pageSel);
				}
				
				gotoPage(0);
				
				// ----- file choices when selected	
				function showFileChoices(idx:int):void
				{
					stage.removeEventListener(MouseEvent.MOUSE_DOWN, clkHandler);
					men.visible = false;
					var choi:Sprite = 
					utils.createNoTitleChoices(Vector.<String>(["打开","删除","取消"]), 
											Vector.<Function>([
											function():void 			// OPEN FILE
											{
												trace("open "+projects[idx].id);
												restoreFromData(projects[idx].data, projects[idx].id);	// imports the data string
												undoStk = [];
												redoStk = [];
												closeMen();
												choi.parent.removeChild(choi);
											},
											function():void 			// DELETE FILE
											{
												closeMen();
												var ldr:URLLoader = new URLLoader();
												function onComplete(ev:Event):void
												{
													trace("project "+projects[idx].id+" removed: "+ldr.data);
													ldr.removeEventListener(Event.COMPLETE, onComplete);
												}
												ldr.addEventListener(Event.COMPLETE, onComplete);
												
												ldr.load(new URLRequest(baseUrl + "?n=api&a=scheme&c=scheme&m=del&id=" + projects[idx].id + "&token=" + userToken));
												choi.parent.removeChild(choi);
											},
											function():void 			// CANCEL
											{
												men.visible = true;
												choi.parent.removeChild(choi);
												stage.addEventListener(MouseEvent.MOUSE_DOWN, clkHandler);
											}]), 100);
					choi.x = (stage.stageWidth - choi.width) / 2;
					choi.y = (stage.stageHeight - choi.height) / 2;
					addChild(choi);
				}
				
				function closeMen():void 
				{
					stage.removeEventListener(MouseEvent.MOUSE_DOWN, clkHandler);
					enableI();
					if (men.parent != null) 
						men.parent.removeChild(men);
				}
				function clkHandler(ev:Event):void
				{
					var mx:int = stage.mouseX;
					var my:int = stage.mouseY;
					if (men.hitTestPoint(mx, my)==false)
						closeMen();
					else if (pageSel.hitTestPoint(mx, my))
					{
						for (var i:int = 0; i < pageSel.numChildren; i++)
							if (pageSel.getChildAt(i).hitTestPoint(mx, my))
								gotoPage(i);
					}
					else if (con.hitTestPoint(mx, my))
					{
						for (i = 0; i < con.numChildren; i++)
							if (con.getChildAt(i).hitTestPoint(mx, my))
								showFileChoices(i);
					}
				}
				stage.addEventListener(MouseEvent.MOUSE_DOWN, clkHandler);
				men.x = (stage.stageWidth - men.width) / 2;
				men.y = (stage.stageHeight - men.height) / 2;
				addChild(men);
			}
			
			// ----- get project saves from server
			function onComplete(ev:Event):void
			{
				var projects:Array = JSON.parse(ldr.data).projects;
				
				if (projects.length > 0)
				{
					var Btns:Vector.<Sprite> = new Vector.<Sprite>();
					for (var i:int=0; i<projects.length; i++)
					{
						try {
							var btn:Sprite = makeBtn(JSON.parse(projects[i].data),projects[i].isshare>0)
							Btns.push(btn);	// create button with icon and label
						} 
						catch (e:Error)
						{
							trace("Load Data Error, "+e);
						}
					}
					createMenu(projects, Btns);
				}
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
						fileRef.upload(new URLRequest(baseUrl + "?n=api&a=scheme&c=scheme_pic&m=add&schemeid=" + properties.saveId + "token=" + userToken));
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
			function onCancel(evt:Event):void 			{ trace("The browse request was canceled by the user."); enableI(); } 
			function onIOError(evt:IOErrorEvent):void 	{ trace("There was an IO Error.");	enableI(); }
			function onSecurityError(evt:Event):void  	{ trace("There was a security error."); enableI();}
		}//endfunction
		
		//=============================================================================
		// Main loop, resizes elements
		//=============================================================================
		private var prevLHSSelected:Page = null;
		private var prevW:int=0;
		private var prevH:int=0;
		private function enterFrameHandler(ev:Event):void
		{
			var sw:int = stage.stageWidth;
			var sh:int = stage.stageHeight;
			
			// ----- switch page
			if (LHS.selected!=prevLHSSelected)
			{
				prevLHSSelected = LHS.selected;
				target = null;
				updateCanvas();
			}
			canvas.x = (sw + main.L.width-main.R.width)/2;
			canvas.y = (sh + main.T.height-main.B.height)/2;
			grid.x = canvas.x;
			grid.y = canvas.y;
			paper.x = canvas.x;
			paper.y = canvas.y;
			
			// ----- 
			if (target != null) 
			{
				main.P.visible = true;
				if (target.data != null)
				{
					btnEditCombo.x = canvas.x + target.Corners[0].x * canvas.scaleX+5;
					btnEditCombo.y = canvas.y + target.Corners[0].y * canvas.scaleY+5;
					main.addChild(btnEditCombo);
				}
				else if (btnEditCombo.parent != null)
					btnEditCombo.parent.removeChild(btnEditCombo);
					
			}
			else 
			{
				main.P.visible = false;
				if (btnEditCombo.parent != null)
					btnEditCombo.parent.removeChild(btnEditCombo);
			}
			if (main.P.visible)
			{
				var page:Page = LHS.selected;
				var ib:MovieClip = main.P.l as MovieClip;
				if (page.Pics.indexOf(target)==page.Pics.length-1)	// if already at top 
				{
					ib.b1.visible = false;
					ib.b2.visible = false;
				}
				else
				{
					ib.b1.visible = true;
					ib.b2.visible = true;
				}
				if (page.Pics.indexOf(target)==0)					// if already at bottom
				{
					ib.b3.visible = false;
					ib.b4.visible = false;
				}
				else
				{
					ib.b3.visible = true;
					ib.b4.visible = true;
				}
				ib.b5.visible = false;
				ib.b6.visible = false;
				if (target is GroupImage)
				{
					if (page.Pics.indexOf(target)==-1)					// group pic not in page
						ib.b5.visible = true;
					else
						ib.b6.visible = true;
				}
				
				var xoff:int=ib.getChildAt(1).x;
				for (var i:int=1; i<ib.numChildren; i++)
					if (ib.getChildAt(i).visible)
					{
						ib.getChildAt(i).x = xoff;
						xoff += ib.getChildAt(i).width+5;
					}
			}//endif
			
			if (prevW==sw && prevH==sh) return;
			
			trace("chkAndResize sw,sh="+sw+","+sh+"   prevW,prevH="+prevW+","+prevH);
			prevW = sw;
			prevH = sh;
			
			main.R.width = 300;	// hack!!
			
			main.R.x = sw-main.R.width;
			main.T.r.x = sw - main.L.width - main.R.width-main.T.r.width+1;
			main.T.m.width = sw - main.T.l.width - main.T.r.width - main.L.width - main.R.width+1;
			main.L.m.height = sh - main.L.t.height - main.L.b.height;
			main.L.b.y = sh - main.L.b.height;
			main.R.m.height = sh - main.R.t.height - main.R.b.height+2;
			main.R.b.y = sh - main.R.b.height;
			main.B.y = sh - main.B.height;
			main.B.r.x = sw - main.L.width - main.R.width - main.B.r.width;
			main.B.m.width = sw - main.L.width - main.R.width - main.B.l.width - main.B.r.width;
			
			main.P.l.getChildAt(0).width = sw-main.L.width-main.R.width;
			
			LHS.canvas.y = main.L.t.height;
			LHS.resize(sh-main.L.t.height-main.L.b.height);
			if (RHS!=null)
			{
				RHS.canvas.x = main.R.x;
				trace("RHS.canvas.x="+RHS.canvas.x);
				RHS.canvas.y = main.R.t.height;
				RHS.resize(sh-main.R.t.height);
			}
			
			//prn("Mem:"+System.totalMemory);
		}//endfunction
		
		//=============================================================================
		// do menu functions if top/bottom menu buttons clicked 
		//=============================================================================
		private function menuAreaClicked():Boolean
		{
			var mx:int = stage.mouseX;
			var my:int = stage.mouseY;
			
			// ----- chk if top left buttons pressed
			if (main.T.l.hitTestPoint(mx,my))
			{
				if (main.T.l.b1.hitTestPoint(mx,my))		// show file menu
				{
					var fo:Sprite = showFileOptions();
					fo.x = main.T.l.b1.x+main.T.l.x+main.T.x;
					fo.y = main.T.l.b1.y+main.T.l.b1.height;
					//showSaveLoad(function():void {disableClick=false;});
				}
				else if (main.T.l.b2.hitTestPoint(mx,my))	// details
				{
					showProjectProperties();
				}
				else if (main.T.l.b3.hitTestPoint(mx,my))	// 
				{
					showItemsList();
				}
				else if (main.T.l.b4.hitTestPoint(mx,my))	// 
				{
					showSlideShow();
				}
				else if (main.T.l.b5.hitTestPoint(mx,my))	// 
				{
					if (stage.displayState!=StageDisplayState.FULL_SCREEN)
						stage.displayState = StageDisplayState.FULL_SCREEN;
					else
						stage.displayState = StageDisplayState.NORMAL;
				}
				else if (main.T.l.b6.hitTestPoint(mx,my))	// undo
				{	
					trace("undo");
					if (undoStk.length>1)
					{
						redoStk.push(undoStk.pop());
						restoreFromData(undoStk[undoStk.length-1]);
					}
				}
				else if (main.T.l.b7.hitTestPoint(mx,my))	// redo
				{
					trace("redo");
					if (redoStk.length>0)
					{
						undoStk.push(redoStk.pop());
						restoreFromData(undoStk[undoStk.length-1]);
					}
				}
				return true;
			}
			
			// ----- chk if top right buttons pressed
			if (main.T.r.hitTestPoint(mx,my))
			{
				if (main.T.r.b1.hitTestPoint(mx,my))		// add text
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
					arrow = new Arrow(properties.defaArrowColor);
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
				return true;
			}
			
			// ----- chk if bottom left buttons pressed
			if (main.B.l.hitTestPoint(mx, my))
			{
				return true;
			}
			
			// ----- chk if bottom right buttons pressed
			if (main.B.r.hitTestPoint(mx,my))
			{
				if (main.B.r.b1.hitTestPoint(mx,my))		// set bg
				{
					showSetAsBackground();
				}
				else if (main.B.r.b2.hitTestPoint(mx,my))	// upload user image
				{
					userSelectAndUploadImage();
				}
				return true;
			}
			
			// ----- if pics controls clicked
			if (main.P.l.visible && target!=null && main.P.l.hitTestPoint(mx,my))
			{
				var ib:MovieClip = main.P.l as MovieClip;
				var page:Page = LHS.selected;
				if (ib.b1.visible && ib.b1.hitTestPoint(mx,my))		// TOP LAYER
				{
					page.Pics.splice(page.Pics.indexOf(target), 1);
					page.Pics.push(target);
				}
				else if (ib.b2.visible && ib.b2.hitTestPoint(mx,my))	// MOVE UP
				{
					if (page.Pics.indexOf(target)<page.Pics.length-1)
					{
						var uidx:int = page.Pics.indexOf(target);
						page.Pics[uidx] = page.Pics[uidx+1];
						page.Pics[uidx+1] = target;
					}
				}
				else if (ib.b3.visible && ib.b3.hitTestPoint(mx,my))	// MOVE DOWN
				{
					if (page.Pics.indexOf(target)>0)
					{
						var didx:int = page.Pics.indexOf(target);
						page.Pics[didx] = page.Pics[didx-1];
						page.Pics[didx-1] = target;
					}
				}
				else if (ib.b4.visible && ib.b4.hitTestPoint(mx,my))	// BOTTOM LAYER
				{
					page.Pics.splice(page.Pics.indexOf(target), 1);
					page.Pics.unshift(target);
				}
				else if (ib.b5.visible && ib.b5.hitTestPoint(mx,my))	// GROUP
				{
					if (target is GroupImage && page.Pics.indexOf(target)==-1)	// ----- group pics not in page
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
				else if (ib.b6.visible && ib.b6.hitTestPoint(mx,my))	// UNGROUP
				{
					if (target is GroupImage && page.Pics.indexOf(target) != -1)	// grp pic in page
					{
						gidx = page.Pics.indexOf(target);
						page.Pics.splice(gidx, 1);			// remove grp pic
						I = (GroupImage)(target).Images;
						for (k = I.length - 1; k > -1; k-- )	// add children pics
							page.Pics.splice(gidx, 0, I[k]);
					}
				}
				else if (ib.b7.visible && ib.b7.hitTestPoint(mx,my))	// TRASH
				{
					page.Pics.splice(page.Pics.indexOf(target),1);
					target = null;
				}
				else if (ib.b8.visible && ib.b8.hitTestPoint(mx,my))	// LOCK
				{
					target.locked = !target.locked;
					trace("target.locked="+target.locked);
				}
				else if (ib.b9.visible && ib.b9.hitTestPoint(mx,my))	// CROP
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
				return true;
			}
			
			if (propMenu != null && propMenu.parent != null && propMenu.hitTestPoint(mx, my))
				return true;
			
			if (btnEditCombo.parent != null && btnEditCombo.hitTestPoint(mx, my))
			{
				if (target != null)
				{
					if (btnEditCombo.getChildAt(0).hitTestPoint(mx, my)) 
						navigateToURL(new URLRequest(baseUrl + "?a=tools&c=flash&id=" + target.id));
					else if (btnEditCombo.getChildAt(1).hitTestPoint(mx, my))
						MenuUtils.loadAsset(target.url, function(bmp:Bitmap):void 
						{ 
							target.bmd = bmp.bitmapData;
							updateCanvas();
						}, true);
				}
				return true;
			}
			
			return false;
		}//endfunction
		
		//=============================================================================
		// start pic transform and move, skew if clicked
		//=============================================================================
		private function mouseDownHandler(ev:Event=null):void
		{
			var mX:int = canvas.stage.mouseX;
			var mY:int = canvas.stage.mouseY;
			
			// ----- return if hits UI elements -------------------------------
			if (disableClick>0 ||menuAreaClicked())	return;
			
			if (arrow != null && arrow.canvas.hitTestPoint(mX, mY)) arrow.onMouseDown();
			
			var page:Page = LHS.selected;
			
			// ----- find text being clicked ----------------------------------
			for (var i:int=page.Txts.length-1; i>-1; i--)
				if (page.Txts[i].hitTestPoint(mX, mY))
				{
					editText(page.Txts[i]);
					target = null;
					if (picResizeUI.parent!=null)
						picResizeUI.parent.removeChild(picResizeUI);
					return;
				}
				
			mouseDownT = getTimer();
			prevMousePt = new Point(canvas.mouseX, canvas.mouseY);
			
			if (target == null) return;
			
			// ----- if pic controls clicked ----------------------------------
			var csr:MovieClip = (MovieClip)(picResizeUI.getChildAt(picResizeUI.numChildren - 1));	// the follow cursor
			if (!target.locked && picResizeUI.hitTestPoint(mX, mY,true))
			{
				if (csr.visible && csr.currentFrame==3)	// rotating cursor
				{
					trace("frame==3 rotate");
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
				else 
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
				}
				// ----- if clicked follow csr 
				if (csr.visible)
				{
					trace("csr visible!!");
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
						trace("scale Image!!!");
						var prevScale:Number = 1;
						mouseMoveFn = function():void 		// ----- scale image
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
			var csr:MovieClip = (MovieClip)(picResizeUI.getChildAt(picResizeUI.numChildren - 1));
			if (target != null && !target.locked)
			{
				var curPt:Point = new Point(canvas.mouseX, canvas.mouseY);
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
						(main.P.visible && main.P.hitTestPoint(stage.mouseX, stage.mouseY)) || 
						main.B.hitTestPoint(stage.mouseX, stage.mouseY) || 
						main.L.hitTestPoint(stage.mouseX, stage.mouseY) || 
						main.R.hitTestPoint(stage.mouseX, stage.mouseY) ||
						(btnEditCombo.parent!=null && btnEditCombo.hitTestPoint(stage.mouseX, stage.mouseY)))
						csr.visible = false;
				}
				if (csr.visible)
				{
					if (disableClick<=0) Mouse.hide();
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
			if (disableClick>0 || picResizeUI.parent == null) 
			{
				csr.visible = false;
				Mouse.show();
			}
		}//endfunction
		
		//=============================================================================
		// 
		//=============================================================================
		private	var mouseUpFn:Function = null;
		private function mouseUpHandler(ev:Event=null):void
		{
			var mX:int = stage.mouseX;
			var mY:int = stage.mouseY;
			
			var curMousePt:Point = new Point(canvas.mouseX, canvas.mouseY);
			
			// ----- return if hits UI elements -------------------------------
			if (disableClick>0)
				return;
				
			main.graphics.clear();
			if (mouseUpFn!=null) mouseUpFn();
			var page:Page = LHS.selected;
			
			var prevTarg:Image = target;
			if (prevMousePt != null && prevMousePt.subtract(curMousePt).length < 1) 
				target = null;		// deselect target if clicked t same spot after some time
			
			// ----- find all images under cursor
			if (mouseMoveFn==null && prevMousePt != null)	// mouseMoveFn==null when no prev selection
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
			
			mouseMoveFn = null;
			
			// ----- chk text being clicked ----------------------------------
			for (var i:int=page.Txts.length-1; i>-1; i--)
				if (page.Txts[i].hitTestPoint(mX, mY))
				{
					target = null;
					return;
				}
			
			// ----- chk if arrow or color square clicked ---------------------
			if (getTimer() - mouseDownT < 250)
			{
				trace("short click!");
				// ----- find arrow being clicked ---------------------------------
				arrow = null;
				for (i=page.Arrows.length-1; i>-1; i--)
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
				if (prevTarg != null && 
					prevTarg.url != null && 
					prevTarg.url.charAt(0) == "#" &&
					pointInPoly(curMousePt,prevTarg.Corners))
				{
					target = prevTarg;
					editColorSquare(target);
				}
			}
			
			// ----- check and add undo
			if (!LHS.canvas.hitTestPoint(stage.mouseX,stage.mouseY) && 
				(RHS==null || !RHS.canvas.hitTestPoint(stage.mouseX,stage.mouseY)) &&
				!main.T.hitTestPoint(stage.mouseX,stage.mouseY))
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
			if (LHS == null) return;
			
			trace("updateCanvas");
			
			// ----- updates page background ------------------------
			updatePaper();
			var page:Page = LHS.selected;
			
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
				picResizeUI.graphics.clear();
				picResizeUI.graphics.lineStyle(0, 0x3399AA);
				var cn:int = target.Corners.length;
				picResizeUI.graphics.moveTo(target.Corners[cn-1].x, target.Corners[cn-1].y);
				for (i=0; i < target.Corners.length; i++)
				{
					setChildPosn(picResizeUI,i,new Point((target.Corners[i].x+target.Corners[(i+1)%cn].x)/2,(target.Corners[i].y+target.Corners[(i+1)%cn].y)/2));
					setChildPosn(picResizeUI, i + 4, target.Corners[i]);
					picResizeUI.graphics.lineTo(target.Corners[i].x, target.Corners[i].y);
				}
				for (i=0; i < picResizeUI.numChildren; i++)
				{
					if (target.locked)	picResizeUI.getChildAt(i).visible = false;
					else				picResizeUI.getChildAt(i).visible = true;
				}
				var csr:MovieClip = (MovieClip)(picResizeUI.getChildAt(picResizeUI.numChildren - 1));	// the follow cursor
				csr.x = picResizeUI.mouseX;
				csr.y = picResizeUI.mouseY;
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
						var D:Object = Pics[j].data;
						//trace("prod data "+i+" : "+ prnObject(D));
						for (var k:* in D)
						{
							var value:String = null;
							if (D[k].attribute is String)
							{
								//trace("WEIRD!!!! " + D[k].attribute);
								value = D[k].attribute;
							}
							else if (D[k].attribute!=null)
								value = JSON.stringify(D[k].attribute);
							if (value != null && A.indexOf(value) == -1)	
							{
								trace("value="+value);
								A.push(value);
							}
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
			if (disableClick) return;
			if (ev.keyCode==16)		keyShift = true;
			if (ev.keyCode==17)		keyControl = true;
		}//endfunction
		
		//=============================================================================
		// hot keys trigger
		//=============================================================================
		private function keyUpHandler(ev:KeyboardEvent):void
		{
			if (disableClick) return;
			if (ev.keyCode==16)		keyShift = false;
			if (ev.keyCode==17)		keyControl = false;
			
			var page:Page = LHS.selected;
			
			if (keyControl)
			{
				if (ev.keyCode==90)		// ctrl Z
				{
					trace("keyup undo");
					if (undoStk.length>1)
					{
						redoStk.push(undoStk.pop());
						restoreFromData(undoStk[undoStk.length-1]);
					}
				}
				if (ev.keyCode==89)		// ctrl Y
				{
					trace("keyup redo");
					if (redoStk.length>0)
					{
						undoStk.push(redoStk.pop());
						restoreFromData(undoStk[undoStk.length-1]);
					}
				}
			}
			
			if (target!=null)
			{
				if (ev.keyCode==8 || ev.keyCode==46)	// delete
				{
					trace("keyup delete");
					if (page.Pics.indexOf(target) != -1)
						page.Pics.splice(page.Pics.indexOf(target),1);
					target = null;
					updateCanvas();
				}
				else if (keyControl && ev.keyCode==71)	// ctrl G
				{
					if (keyShift)		// ctrl shft G => ungroup
					{
						if (target is GroupImage && page.Pics.indexOf(target) != -1)	// grp pic in page
						{
							var gidx:int = page.Pics.indexOf(target);
							page.Pics.splice(gidx, 1);			// remove grp pic
							I = (GroupImage)(target).Images;
							for (var k:int = I.length - 1; k > -1; k-- )	// add children pics
								page.Pics.splice(gidx, 0, I[k]);
						}
					}
					else
					{
						if (target is GroupImage && page.Pics.indexOf(target)==-1)	// ----- group pics not in page
						{
							var I:Vector.<Image> = (GroupImage)(target).Images;
							gidx = 0;
							for (k = I.length - 1; k > -1; k-- )
							{
								if (gidx < page.Pics.indexOf(I[k]))	// remove children pics from page
									gidx = page.Pics.indexOf(I[k]);
								page.Pics.splice(page.Pics.indexOf(I[k]), 1);
							}
							page.Pics.splice(gidx, 0, target);	// add grp pic to page
						}
					}
				}
			}
			
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
					o.b64thumb = (LHSMenu)(v).b64thumb;
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
		public function restoreFromData(s:String,saveId:String=null):void
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
				if (saveId != null) properties.saveId = saveId;
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
					var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme_page_pic&m=add&saveid="+properties.saveId+"&pageid="+P[pidx].pageId+"&token="+userToken);
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
			// ----- generate save thumb in base64
			var bmd:BitmapData = new BitmapData(74,74,false,0xFFFFFF);
			drawCanvasThumb(bmd);
			var jpgEnc:JPGEncoder = new JPGEncoder(80);
			var ba:ByteArray = jpgEnc.encode(bmd);
			var b64enc:Base64Encoder = new Base64Encoder();
			b64enc.encodeBytes(jpgEnc.encode(bmd));
			LHS.b64thumb = b64enc.toString();
			trace("saveToServer thumb:" + LHS.b64thumb);
			addChild(new Bitmap(bmd));
			
			// ----- construct save request
			var dat:Date = new Date();
			var M:Array = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
			
			var ldr:URLLoader = new URLLoader();
			var req:URLRequest = null;
			if (properties.saveId=="")
				req = new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=add&token="+userToken);
			else
				req = new URLRequest(baseUrl+"?n=api&a=scheme&c=scheme&m=edit&token="+userToken+"&id="+properties.saveId);
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
			
			// ----- send data to server
			function onComplete(ev:Event):void
			{
				var o:Object = JSON.parse(ldr.data);
				if (o.data!=null && o.data.id!=null) properties.saveId = o.data.id;
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
			var tf:TextField = utils.createInputText(function():void{},"TEXT",-1,properties.defaTxtSize,properties.defaTxtColor);
			canvas.addChild(tf);
			target = null;
			
			mouseMoveFn = function():void
			{
				tf.x = canvas.mouseX;
				tf.y = canvas.mouseY;
			} 
			
			LHS.selected.Txts.push(tf);
			return tf;
		}//endfunction
		
		//=============================================================================
		// edits the selected textfield on drawing canvas
		//=============================================================================
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
				var s:Sprite = new TextProp();
				
				// ----- font size textfield
				var inTf:TextField = utils.createInputText(function(txt:String):void 
				{
					if (isNaN(parseInt(txt))) return;
					var tff:TextFormat = tf.defaultTextFormat;
					tff.size = parseInt(txt);
					properties.defaTxtSize = tff.size;
					tf.defaultTextFormat = tff;
					tf.setTextFormat(tff);
					showLabelProperties();
				}, properties.defaTxtSize + "", 40);
				inTf.x = 73; 
				inTf.y = 45;
				s.addChild(inTf);
				
				// ----- font color rect
				var colorRect:Sprite = new Sprite();
				colorRect.graphics.beginFill(uint(tf.defaultTextFormat.color+""), 1);
				colorRect.graphics.drawRect(0, 0, 40, 20);
				colorRect.graphics.endFill();
				colorRect.x = 73;
				colorRect.y = 70;
				s.addChild(colorRect);
				colorRect.buttonMode = true;
				
				// ----- ok button
				var okBtn:GeneralBtn = new GeneralBtn();
				setGeneralBtn(okBtn, "确认", 58);
				okBtn.x = 18;
				okBtn.y = 100;
				s.addChild(okBtn);				
				
				// ----- delete button
				var delBtn:GeneralBtn = new GeneralBtn();
				setGeneralBtn(delBtn, "删除", 38);
				delBtn.x = 79;
				delBtn.y = 100;
				s.addChild(delBtn);
				
				function clickHandler(ev:Event):void
				{
					if (colorRect.hitTestPoint(stage.mouseX,stage.mouseY))
					showColorMenu(function(color:uint):void 
						{
							var tff:TextFormat = tf.defaultTextFormat;
							tff.color = color;
							properties.defaTxtColor = color;
							tf.defaultTextFormat = tff;
							tf.setTextFormat(tff);
							showLabelProperties();
						});
					else if (delBtn.hitTestPoint(stage.mouseX, stage.mouseY))
					{
						LHS.selected.Txts.splice(LHS.selected.Txts.indexOf(tf),1);
						if (tf.parent != null) tf.parent.removeChild(tf);
						endEdit();
					}
					else if (okBtn.hitTestPoint(stage.mouseX, stage.mouseY))
					{
						endEdit();
					}
				}
				function removeHandler(ev:Event):void
				{
					s.removeEventListener(MouseEvent.CLICK, clickHandler);
					s.removeEventListener(Event.REMOVED_FROM_STAGE, removeHandler);
				}
				s.addEventListener(MouseEvent.CLICK, clickHandler);
				s.addEventListener(Event.REMOVED_FROM_STAGE, removeHandler);
				
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
				propMenu.x = canvas.x+(tf.x+tf.width+10)*canvas.scaleX;
				propMenu.y = canvas.y+(tf.y)*canvas.scaleY;
				addChild(propMenu);
				
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
			if (propMenu!=null && propMenu.parent!=null)	
				propMenu.parent.removeChild(propMenu);
			propMenu = createColorMenu(function(c:uint):void 
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
			if (cpt.x>0)	propMenu.x = canvas.x + minPt.x*canvas.scaleX-propMenu.width;
			else			propMenu.x = canvas.x + maxPt.x*canvas.scaleX;
			if (cpt.y>0)	propMenu.y = canvas.y + minPt.y*canvas.scaleY-propMenu.height;
			else			propMenu.y = canvas.y + maxPt.y*canvas.scaleY;
			function closeHandler(ev:Event):void
			{
				if (propMenu.hitTestPoint(stage.mouseX, stage.mouseY)) return;
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, closeHandler);
				if (propMenu.parent != null) propMenu.parent.removeChild(propMenu);
			}//endfunction
			stage.addEventListener(MouseEvent.MOUSE_DOWN, closeHandler);
			
			addChild(propMenu);
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
																			properties.defaArrowColor = color;
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
			var wh:Point = new Point(s.colorBox.width, s.colorBox.height);
			
			function clickHandler(ev:Event):void
			{
				if (s.btn.hitTestPoint(stage.mouseX,stage.mouseY))
				{
					trace("?");
					if (callBack!=null) callBack(c);
					if (s.parent!=null) s.parent.removeChild(s);
					return;
				}
				if (s.colorArea.hitTestPoint(stage.mouseX, stage.mouseY, true) == false)
					return;
				var bmd:BitmapData = new BitmapData(1,1,false,0x00000000);
				bmd.draw(s,new Matrix(1,0,0,1,-s.mouseX,-s.mouseY));
				c = bmd.getPixel(0,0);
				
				while (s.colorBox.numChildren>0)	s.colorBox.removeChildAt(0);
				s.colorBox.graphics.clear();
				s.colorBox.graphics.beginFill(c);
				s.colorBox.graphics.drawRoundRect(2,2,wh.x-4,wh.y-4,3,3);
				s.colorBox.graphics.endFill();
				
				var tf:TextField = null;
				if ((c & 0xFF) + ((c >> 8) & 0xFF) + ((c >> 16) & 0xFF) < 128 * 3)
					tf = utils.createText(c.toString(16), -1, 15, 0xFFFFFF);
				else
					tf = utils.createText(c.toString(16), -1, 15, 0x000000);
				tf.selectable = true;
				tf.x = (wh.x-tf.width)/2;
				tf.y = (wh.y-tf.height)/2;
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
			s.filters = [new DropShadowFilter(1, 45, 0x000000, 1, 4, 4, 1)];
			
			s.colorArea.buttonMode = true;
			setGeneralBtn(s.btn, "确认", 58);
			
			return s;
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
			fr.save(ba,properties.name+".pdf");
		}//endfunction
		
		//=============================================================================
		// 
		//=============================================================================
		private function drawCanvasThumb(bmd:BitmapData):void
		{
			// ----- draw on thumbnail of page ----------------------
			trace("drawCanvasThumb()  LHS.selected="+LHS.selected);
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
		
		//===============================================================================================
		// convenience function to set button roll over behavior
		//===============================================================================================
		public static function setGeneralBtn(btn:GeneralBtn,txt:String,w:int=-1):void
		{
			btn.buttonMode = true;
			btn.mouseChildren = false;
			
			if (w != -1)
			{
				btn.m.width = w - btn.l.width - btn.r.width;
				btn.r.x = btn.l.width + btn.m.width;
			}
			btn.tf.text = txt;
			btn.tf.width = btn.l.width + btn.m.width + btn.r.width;
			
			function rollOverHandler(ev:Event):void
			{
				btn.l.gotoAndStop(2);
				btn.m.gotoAndStop(2);
				btn.r.gotoAndStop(2);
				var tff:TextFormat = btn.tf.defaultTextFormat;
				tff.color = 0xFFFFFF;
				btn.tf.setTextFormat(tff);
			}//endfunction
			
			function rollOutHandler(ev:Event):void
			{
				btn.l.gotoAndStop(1);
				btn.m.gotoAndStop(1);
				btn.r.gotoAndStop(1);
				var tff:TextFormat = btn.tf.defaultTextFormat;
				tff.color = 0xCCCCCC;
				btn.tf.setTextFormat(tff);
			}//endfunction
			
			rollOutHandler(null);
			
			function removeHandler(ev:Event):void
			{
				btn.removeEventListener(MouseEvent.MOUSE_OVER, rollOverHandler);
				btn.removeEventListener(MouseEvent.MOUSE_OUT, rollOutHandler);
				btn.removeEventListener(Event.REMOVED_FROM_STAGE, removeHandler);
			}//endfunction
			btn.addEventListener(MouseEvent.MOUSE_OVER, rollOverHandler);
			btn.addEventListener(MouseEvent.MOUSE_OUT, rollOutHandler);
			btn.addEventListener(Event.REMOVED_FROM_STAGE, removeHandler);
			
		}//endfunction
		
	}//endclass
	
}//endpackage


import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.display.Sprite;
import flash.display.MovieClip;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.filters.DropShadowFilter;
import flash.filters.GlowFilter;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.navigateToURL;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.net.URLVariables;
import flash.text.TextField;
import flash.text.TextFormat;


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
	public function Arrow(c:uint=0x334455):void
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
		
		color = c;
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
		head.graphics.lineTo( 4,15);
		head.graphics.lineTo(-4,15);
		head.graphics.endFill();
		
		tail.graphics.clear();
		tail.graphics.beginFill(color);
		tail.graphics.drawCircle(0,0,4);
		tail.graphics.endFill();
		
		canvas.graphics.clear();
		canvas.graphics.lineStyle(1,color,1);
		
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
		if (pic != null)
		{
			pic.drawOn(canvas);	// draws the arrow pic
			canvas.graphics.lineStyle(1,color,1);
			canvas.graphics.moveTo(pic.Corners[0].x, pic.Corners[0].y);
			canvas.graphics.lineTo(pic.Corners[1].x, pic.Corners[1].y);
			canvas.graphics.lineTo(pic.Corners[2].x, pic.Corners[2].y);
			canvas.graphics.lineTo(pic.Corners[3].x, pic.Corners[3].y);
			canvas.graphics.lineTo(pic.Corners[0].x, pic.Corners[0].y);
			canvas.graphics.lineStyle();
		}
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
	public var isPublic:Boolean = false;
	
	public var defaArrowColor:uint = 0x666666;
	public var defaTxtColor:uint = 0x666666;
	public var defaTxtSize:uint = 14;
	public var defaColor:uint = 0x666666;
	
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
		p.isPublic = isPublic;
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
	public var b64thumb:String = null;
	
	public var changeNotify:Function = null;
	
	private var marg:int = 10;
	private var bw:int = 120;

	private var msk:Sprite = null;
	private var con:Sprite = null;				// containing all the btns
	private var scroll:Sprite = null;
	private var pageNumTxt:TextField = null;
	
	private var createSpaceBtn:Sprite = null;
	
	private var dragging:DisplayObject = null;
	
	private var selFrame:Sprite = null;
	private var selMsk:Sprite = null;
	
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
		
		selFrame = new Sprite();				// hilight frame foe selected
		canvas.addChild(selFrame);
		selMsk = new Sprite();					// msk for hilight frame
		selFrame.mask = selMsk;
		selMsk.x = 2;
		selMsk.y = marg;
		canvas.addChild(selMsk);
		
		pageNumTxt = PPTool.utils.createText("1/1");
		canvas.addChild(pageNumTxt);
		
		scroll = new Sprite();					// scrollbar for 
		canvas.addChild(scroll);
		scroll.addChild(new Sprite());
		(Sprite)(scroll.getChildAt(0)).buttonMode = true;
		
		createSpaceBtn = new IcoNewPage();
		createSpaceBtn.buttonMode = true;
		
		canvas.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
		canvas.addEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);
		function addedHandler(ev:Event):void
		{
			canvas.removeEventListener(Event.ADDED_TO_STAGE, addedHandler);
			canvas.parent.addEventListener(MouseEvent.MOUSE_WHEEL, mouseWheelHandler);
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
			createSpaceBtn.x = (con.width - createSpaceBtn.width) / 2;
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
					btn.filters=[new GlowFilter(0xAAAAAA,1,4,4,10)];
				else if ((GlowFilter)(A[0]).strength<1)
					(GlowFilter)(A[0]).strength+=1;
			}
			else
			{
				if (btn.filters.length>0)
				{
					A = btn.filters;
					if (A.length>0 && (GlowFilter)(A[0]).strength>0)
						(GlowFilter)(A[0]).strength-=1;
					else 
						A = null;
					btn.filters = A;
				}
			}	
		}
		
		if (selected != null)
		{
			if (selFrame.width != selected.thumb.width + 4 || selFrame.height != selected.thumb.height + 4)
			{
				selFrame.graphics.beginFill(0x666666, 1);
				selFrame.graphics.drawRect( -2, -2, selected.thumb.width + 4, selected.thumb.height + 4);
				selFrame.graphics.drawRect( 0, 0, selected.thumb.width, selected.thumb.height);
				selFrame.graphics.endFill();
				trace("redrawSelFrame!");
			}
			var pSpace:Space = parentSpace(selected);
			selFrame.x = selected.ico.x+con.x+pSpace.lhsIco.x;
			selFrame.y = selected.ico.y+con.y+pSpace.lhsIco.y;
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
			pageNumTxt.text = (Pages.indexOf(selected) + 1) + "/" + Pages.length;
			if (changeNotify!=null) changeNotify();
			return;
		}
		// ----- allow scrollbar dragging -------------------------
		if (scroll.getChildAt(0).hitTestPoint(mx,my))
		{
			dragging = scroll.getChildAt(0);
			(Sprite)(dragging).startDrag(false, new Rectangle(0, 0, 0, msk.height - dragging.height));
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
					if (changeNotify!=null) changeNotify();
				}
				else if (spc.pointHitsTextfield())
				{}
				else if (spc.pointHitsAddBtn())
				{
					spc.addPage();
					enterFrameHandler(null);
					resize(msk.height+marg*2);	// to refresh scrollbar
					if (changeNotify!=null) changeNotify();
				}
				else if (spc.chkHitThumbCloseBtns())
				{
					// destroyed page
					if (changeNotify!=null) changeNotify();
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
					else
						dragging = btn;		// dragging over page thumb
				}
			}
		}
		
		pageNumTxt.text = (Pages.indexOf(selected) + 1) + "/" + Pages.length;
	}//endfunction
	
	//=============================================================================
	// scrolls by mouseWheel
	//=============================================================================
	private function mouseWheelHandler(ev:MouseEvent):void
	{
		if (canvas.stage!=null && canvas.hitTestPoint(canvas.stage.mouseX, canvas.stage.mouseY))
		{
			var bar:Sprite = (Sprite)(scroll.getChildAt(0));
			bar.y -= ev.delta*5;
			if (bar.y < 0) bar.y = 0;
			if (bar.y > msk.height - bar.height) bar.y = msk.height - bar.height;
			con.y = marg - bar.y / msk.height * con.height;
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
		selMsk.graphics.clear();
		selMsk.graphics.beginFill(0x000000, 1);
		selMsk.graphics.drawRect(-2,-2,bw+10+2,h-marg*2+2);
		selMsk.graphics.endFill();
		
		scroll.graphics.clear();
		drawStripedRect(scroll,0,0,4,h-marg*2,0xFFFFFF,0xF6F6F6,5,10);
		scroll.y = marg;
		scroll.x = msk.width;
		
		pageNumTxt.x = (canvas.width - pageNumTxt.width) / 2;
		pageNumTxt.y = msk.y+msk.height+20;
		
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
															title,-1,14,0xFFFFFF);
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
		var tf:TextField = PPTool.utils.createText(title,-1,12,0x999999);
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
			},title,-1,12,0x666666);
			tf.y = thumb.height;
			tf.x = (thumb.width-tf.width)/2;
			ico.addChild(tf);
		});
	}//endconstr
}//endclass

class RHSMenu
{
	public var canvas:Sprite = null;
	private var dat:Array = null;
	private var Btns:Vector.<Sprite> = null;
	private var con:Sprite = null;	
	private var pageBtns:Sprite = null;
	private var sideBtns:Sprite = null;
	private var sideFns:Vector.<Function> = null;
	
	private var marg:int = 6;
	private var bw:int = 90;
	private var bh:int = 106;
	private var height:int = 600; 
	private var category:int=0;			// current category being displayed
	private var page:int=0;				// current page in category
	
	private var curTab:int = 0;			// assets category tab
	private var subCat:String = "";		// assets subcategory within tab
		
	private var baseUrl:String = "";
	private var userToken:String;
	
	private var getProductItemsData:Function = null;	// passed in function
	public var clickCallBack:Function = null;			// function to return 
	public var updateCanvas:Function = null;
	public var pptool:PPTool = null;
	
	private var searchBar:MovieClip = null;				// the micro ui beneath the tabs
	private var btnFolder:MovieClip = null;				// 
	private var dropDownList:Sprite = null;				// cate sel list
	
	private var LoadFns:Vector.<Function> = null;
	
	private var refreshIco:IcoRefresh = null;
	
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
		
		refreshIco = new IcoRefresh();
		
		con = new Sprite();						// container of buttons
		con.x = marg;
		con.y = marg;
		canvas.addChild(con);
		
		pageBtns = new Sprite();
		pageBtns.buttonMode = true;
		pageBtns.mouseChildren = false;
		canvas.addChild(pageBtns);
		
		canvas.addEventListener(Event.ENTER_FRAME,enterFrameHandler);
		con.addEventListener(MouseEvent.MOUSE_DOWN,mouseDownHandler);
		canvas.addEventListener(MouseEvent.MOUSE_UP,mouseUpHandler);
		
		btnFolder = new BtnFolder();
		btnFolder.buttonMode = true;
		btnFolder.y = -btnFolder.height - 8;
		btnFolder.x = 300-btnFolder.width-5;
		canvas.addChild(btnFolder);
		
		searchBar = new SearchBox();
		searchBar.x = 10;
		searchBar.y = -searchBar.height - 5;
		var inTf:TextField = PPTool.utils.createInputText(function(txt:String):void 
		{	// search!!!
			//inTf.text = "关键词功能缺失!";
			if (curTab == 0)	loadProjs(baseUrl + "?n=api&a=scheme&c=match&m=index&limit=1000&page=1&keyword="+txt+"&token=" + userToken);
			if (curTab == 1)	loadAssets(baseUrl + "?n=api&a=user&c=photo&dirid=0&keyword=" + txt + "&token=" + userToken);
			if (curTab == 2)	inTf.text = "检索功能不做";
			if (curTab == 4)	
			{
				if (subCat == "背景图")	loadAssets(baseUrl + "?n=api&a=scheme&c=scheme_resource&m=index&type=1&limit=20&page=1&keyword=" + txt + "&token=" + userToken);
				if (subCat == "图形图")	loadAssets(baseUrl + "?n=api&a=scheme&c=scheme_resource&m=index&type=3&limit=20&page=1&keyword=" + txt + "&token=" + userToken);
			}			
		},"输入关键字", 80, 11,0xa1a1a1);
		inTf.x = 5;
		inTf.y = (searchBar.height - inTf.height) / 2;
		searchBar.addChild(inTf);
		canvas.addChild(searchBar);
		
		LoadFns = Vector.<Function>([function():void 	// 我的作品
									{
										loadProjs(baseUrl+"?n=api&a=scheme&c=match&m=index&isshare=0&token="+userToken);
										curTab = 0; 
										subCat = "搭配图";
										inTf.text = "输入关键字";
										btnFolder.visible = true; 
										if (dropDownList != null && dropDownList.parent != null)
											dropDownList.parent.removeChild(dropDownList);
									},
									function():void 	// 个人素材
									{
										loadFolders(function (A:Array):void 
										{ 
											trace("loaded folders:" + A); 
											loadAssets(baseUrl + "?n=api&a=user&c=photo&type=" + 1 + "&token=" + userToken, A);
										});
										curTab = 1; 
										subCat = "";
										inTf.text = "输入关键字";
										btnFolder.visible = true; 
										if (dropDownList != null && dropDownList.parent != null)
											dropDownList.parent.removeChild(dropDownList);
									},
									function():void 	// 收藏夹
									{
										loadAssets(baseUrl + "?n=api&a=user&c=favorite&t=product&token=" + userToken);
										curTab = 2; 
										subCat = "产品收藏";
										inTf.text = "输入关键字";
										btnFolder.visible = true;
										if (dropDownList != null && dropDownList.parent != null)
											dropDownList.parent.removeChild(dropDownList);
										dropDownList = PPTool.utils.createDropDownList(Vector.<String>(["产品收藏", "搭配收藏", "灵感图收藏"]),"产品收藏",
										function(va:String):void 
										{
											subCat = va;
											if (va == "产品收藏")
												loadAssets(baseUrl + "?n=api&a=user&c=favorite&t=product&token=" + userToken);
											if (va == "搭配收藏")
												loadAssets(baseUrl + "?n=api&a=user&c=favorite&t=match&token=" + userToken);
											if (va == "灵感图收藏")
												loadAssets(baseUrl + "?n=api&a=user&c=favorite&t=photo&token=" + userToken);
										},100, 5,0x999999);
										dropDownList.x = searchBar.x + searchBar.width + 5;
										dropDownList.y = searchBar.y+(searchBar.height-dropDownList.height)/2;
										canvas.addChild(dropDownList);
									},
									function():void 	// 上传的素材
									{ 
										loadAssets(baseUrl+"?n=api&a=scheme&c=scheme_pic&schemeid="+pptool.properties.saveId+"&token="+userToken);	
										curTab = 3;
										subCat = "";
										inTf.text = "输入关键字";
										btnFolder.visible = false; 
										if (dropDownList != null && dropDownList.parent != null)
											dropDownList.parent.removeChild(dropDownList);
									},
									function():void 	// 公共素材
									{ 
										loadAssets(baseUrl + "?n=api&a=scheme&c=scheme_resource&m=index&type=1&token=" + userToken);
										curTab = 4; 
										subCat = "背景图";88
										inTf.text = "输入关键字";
										btnFolder.visible = false; 
										if (dropDownList != null && dropDownList.parent != null)
											dropDownList.parent.removeChild(dropDownList);
										dropDownList = PPTool.utils.createDropDownList(Vector.<String>(["背景图", "图形图"]),"背景图",
										function(va:String):void 
										{
											subCat = va;
											if (va == "背景图")
												loadAssets(baseUrl + "?n=api&a=scheme&c=scheme_resource&m=index&type=1&token=" + userToken);
											if (va == "图形图")
												loadAssets(baseUrl + "?n=api&a=scheme&c=scheme_resource&m=index&type=3&token=" + userToken);
										},100, 5,0x999999);
										dropDownList.x = searchBar.x + searchBar.width + 5;
										dropDownList.y = searchBar.y+(searchBar.height-dropDownList.height)/2;
										canvas.addChild(dropDownList);
									}]);
		
		// ----- create side selection tabs
		createTabs(Vector.<String>(["我的搭配", "个人素材", "收藏夹", "上传的素材", "公共素材"]), LoadFns);
		
		setTabHighlight(0);	// default tab selection to 0
		LoadFns[0]();		// default load assets 0
	}//endconstr
	
	//=============================================================================
	// create the tabs at the top of the menu
	//=============================================================================
	private function createTabs(sideLabels:Vector.<String>,fns:Vector.<Function>):void
	{
		if (sideBtns==null)	
			sideBtns = new Sprite();
		else
			while (sideBtns.numChildren>0)
				sideBtns.removeChildAt(0);
		
		sideFns = fns;
		
		var offX:int=0;
		for (var i:int=0; i<sideLabels.length; i++)
		{
			var btn:Sprite= new Tab();
			var tf:TextField = PPTool.utils.createText(sideLabels[i],-1,11,0xFFFFFF);
			tf.x = btn.getChildAt(0).width-2;
			tf.y = (btn.height - tf.height) / 2;
			btn.addChild(tf);
			btn.getChildAt(1).width = tf.width-4;
			btn.getChildAt(2).x = btn.getChildAt(1).x+btn.getChildAt(1).width
			btn.x = offX;
			offX += btn.width-3;
			sideBtns.addChild(btn);
			btn.buttonMode = true;
			btn.mouseChildren = false;
		}
		sideBtns.y = -sideBtns.height-35;
		canvas.addChildAt(sideBtns, 0);
		
		refreshIco.x = 250 - sideBtns.getChildAt(0).x;
		refreshIco.y = 30;
		(Sprite)(sideBtns.getChildAt(0)).addChild(refreshIco);
	}//endfunction
	
	//=============================================================================
	// sets the selected tab at the top of the menu
	//=============================================================================
	private function setTabHighlight(idx:int):void
	{
		for (var i:int=0; i<sideBtns.numChildren; i++)
		{
			var btn:Sprite = (Sprite)(sideBtns.getChildAt(i));
			var tf:TextField = (TextField)(btn.getChildAt(3));
			var tff:TextFormat = tf.getTextFormat();
			if (i==idx)
			{
				tff.color = 0xc1c1c1;
				for (var j:int = 0; j < 3; j++)
					(MovieClip)(btn.getChildAt(j)).gotoAndStop(1);
				btn.addChild(refreshIco);
				sideFns[i]();
				refreshIco.x = 250 - btn.x;
				refreshIco.y = 30;
				btn.addChild(refreshIco);
			}
			else
			{
				tff.color = 0xFFFFFF;
				for (j= 0; j < 3; j++)
					(MovieClip)(btn.getChildAt(j)).gotoAndStop(2);
			}
			tf.setTextFormat(tff);
		}
	}//endfunction
	
	//=============================================================================
	// loads specified asset type, external loaded pics
	//=============================================================================
	private function loadProjs(url:String):void
	{
		trace("loadProjs(url="+url+")");
		sideBtns.visible = false;
		var ldr:URLLoader = new URLLoader();
		var req:URLRequest = new URLRequest(url);
		ldr.load(req);
		ldr.addEventListener(Event.COMPLETE, onComplete);  
		function onComplete(e:Event):void
		{	// ----- when received data from server
			var o:Object = JSON.parse(ldr.data);
			//trace("projs="+PPTool.prnObject(o));
			var projs:Array = o.projects;
			Btns = new Vector.<Sprite>();
			dat = projs;
			for (var i:int=0; i<projs.length; i++)
			{
				//trace("proj[" + i + "]=" + projs[i]);
				var proj:Object = projs[i];
				proj.pic = proj.image;
				var s:Sprite = new Sprite();
				var tf:TextField = PPTool.utils.createText(proj.name,-1,12,0x666666);
				if (tf.width>bw)
				{
					tf.wordWrap = true;
					tf.width = bw;
				}
				tf.y = bh-tf.height;
				s.addChild(tf);
				s.graphics.beginFill(0xFFFFFF, 1);
				s.graphics.drawRect(0, 0, bw, bh);
				s.graphics.endFill();
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
					MenuUtils.loadAsset(picUrl,function(pic:Bitmap):void
					{
						if (Btns.length>lidx)
						{
							var tf:TextField = (TextField)(Btns[lidx].getChildAt(0));
							if (pic == null) pic = new Bitmap(new BitmapData(bw, bh - tf.height, false, 0xAA0000));
							var sc:Number = Math.min(bw / pic.width, (bh - tf.height) / pic.height);
							pic.scaleX = pic.scaleY = sc;
							if (pic.width > bw) pic.width = bw;
							if (pic.height > bh-tf.height) pic.height = bh-tf.height;
							pic.x = (bw - pic.width) / 2;
							pic.y = (bh-tf.height - pic.height) / 2;
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
	// loads the stupid folders
	//=============================================================================
	private function loadFolders(callBack:Function):void
	{
		//sideBtns.visible = false;
		var req:URLRequest = new URLRequest(baseUrl+"?n=api&a=user&c=photo_dir");
		var ldr:URLLoader = new URLLoader(req);
		req.method = "post";  
		var vars:URLVariables = new URLVariables();  
		vars.token = userToken;  
		req.data = vars;
		ldr.load(req);
		ldr.addEventListener(Event.COMPLETE, onComplete);  
		function onComplete(e:Event):void
		{	// ----- when received data from server
			trace("loadFolders ldr.data="+ldr.data);
			var folders:Array = JSON.parse(ldr.data).data;
			callBack(folders);
		}
	}//endfunction
	
	//=============================================================================
	// loads specified asset type, external loaded pics
	//=============================================================================
	private function loadAssets(url:String,foldersDat:Object=null):void
	{
		sideBtns.visible = false;
		var req:URLRequest = new URLRequest(url);
		var ldr:URLLoader = new URLLoader(req);
		req.method = "post";  
		var vars:URLVariables = new URLVariables();  
		vars.token = userToken;  
		req.data = vars;
		ldr.load(req);
		ldr.addEventListener(Event.COMPLETE, onComplete);  
		function onComplete(e:Event):void
		{	
			var i:int = 0;
			// ----- when received data from server
			try {
				var o:Object = JSON.parse(ldr.data);
				dat = o.data as Array;
			} 
			catch (e:Error)
			{
				trace("ERROR!!!! loadAssets(" + url + ") : \n" + ldr.data);
				o = {data:[]};
				dat = [];
			}
			
			//trace("loadAssets(" + url + ") : \n" + PPTool.prnObject(dat));
			Btns = new Vector.<Sprite>();
			
			// ----- fill with new Btns
			if (dat!=null)
			for (i=0; i<dat.length; i++)
			{
				var s:Sprite = new Sprite();
				var tf:TextField = PPTool.utils.createText(dat[i].photoname, -1, 12, 0x666666);
				if (tf.text == "")	tf = PPTool.utils.createText(dat[i].name, -1, 12, 0x666666);
				tf.y = bh-tf.height;
				s.addChild(tf);
				s.graphics.beginFill(0xFFFFFF, 1);
				s.graphics.drawRect(0, 0, bw, bh);
				s.graphics.endFill();
				s.buttonMode = true;
				s.mouseChildren = false;
				Btns.push(s);
			}
			
			// ----- if have folders add them to front
			if (foldersDat != null)
			{
				//trace("url.split(&dirid=)"+url.split("&dirid="))
				// ----- find the current dirId -------------------------------
				var dirId:int = 0;
				if (url.indexOf("&dirid=")!=-1)
					dirId= parseInt(url.split("&dirid=")[1].split("&")[0]);
				var parentId:int = 0;
				var Fdrs:Array = [];
				for (i = foldersDat.length - 1; i > -1; i--)
				{
					Fdrs.unshift(foldersDat[i]);
					if (foldersDat[i].id == dirId)
						parentId = foldersDat[i].parentid;
				}
				
				trace("dirId="+dirId+"  parentId="+parentId);
				if (dirId != 0)	{ trace("CREATE PARENT FOLDER"); Fdrs.unshift( { parentid:dirId, id:parentId, dirname:"[..]" } ); }	// return to parent directory
				
				function setLoadSubfolderFn(d:Object):void
				{
					d.loadSubFolderFn = function():void 
					{
						trace("loadSubFolderFn  d.id="+d.id+"  parentid="+parentId);
						var A:Array = url.split("&dirid=");
						if (A.length > 1)
						{
							var en:String = A[1];
							while (en.length > 0 && en.charAt(0) != "&") en = en.substr(1);
							loadAssets(A[0] + "&dirid=" + d.id + en,foldersDat);
						}
						else 
							loadAssets(url + "&dirid=" + d.id,foldersDat);
					}
				}//endfunction
				
				for (i=Fdrs.length-1; i>-1; i--)
				{
					//trace("foldersDat["+i+"].parentid="+foldersDat[i].parentid+"   dirId="+dirId);
					if (Fdrs[i].parentid == dirId)
					{
						dat.unshift(Fdrs[i]);
						setLoadSubfolderFn(Fdrs[i])
						// create icon sprite
						s = new Sprite();			
						s.graphics.beginFill(0x000066, 0);
						s.graphics.drawRect(0, 0, bw, bh);
						s.graphics.endFill();
						var tf:TextField = PPTool.utils.createText(Fdrs[i].dirname,-1,12,0x666666);
						tf.y = bh - tf.height;
						tf.x = (bw - tf.width) / 2;
						s.addChild(tf);
						Btns.unshift(s);
						var ico:Sprite = null;
						if (Fdrs[i].id==parentId)
							ico = new IcoParentFolder();
						else 
							ico = new IcoAssetFolder();
						ico.x = (s.width - ico.width) / 2;
						ico.y = (s.height - tf.height - ico.height) / 2;
						s.addChild(ico);
					}
				}
			}//endif
			
			pageTo(page);
			
			// ----- start loading the pics 
			var lidx:int=0;
			function loadNext():void
			{
				if (dat != null && lidx <dat.length)
				{
					if (dat[lidx].pic != null)
					{
						var picUrl:String = baseUrl + "thumb.php?src="+dat[lidx].pic+"&w=100"
						MenuUtils.loadAsset(picUrl,function(pic:Bitmap):void
						{
							if (lidx >= Btns.length)	return;
							if (pic == null)	pic = new Bitmap(new BitmapData(bw, bh - tf.height, false, 0xFF0000));
							var tf:TextField = (TextField)(Btns[lidx].getChildAt(0));
							var sc:Number = Math.min(bw / pic.width, (bh - tf.height) / pic.height);
							pic.scaleX = pic.scaleY = sc;
							if (pic.width > bw) pic.width = bw;
							if (pic.height > bh-tf.height) pic.height = bh-tf.height;
							pic.x = (bw - pic.width) / 2;
							pic.y = (bh-tf.height - pic.height) / 2;
							Btns[lidx].addChild(pic);
							dat[lidx].bmd = pic.bitmapData;
							tf.x = (pic.width-tf.width)/2;
							lidx++;
							loadNext();
						});
					}
					else
					{
						lidx++;
						loadNext();
					}
				}
				//if (dat != null && lidx >= dat.length)	sideBtns.visible = true;
			} //endfunction
			loadNext();
		
			sideBtns.visible = true;
		}
	}//endfunction
	
	//=============================================================================
	// loads the arrow box selections
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
				trace("parsing "+A[i]);
				if (A[i] is String) A[i] = JSON.parse(A[i]);
				if (A[i] is String) trace("loadProductsERROR! A["+i+"]="+A[i]);
				if (A[i].name != null) 	tf.text = A[i].name;
				else					tf.text = "???";
			}
			else
				tf.text = "???";
			tf.selectable = false;
			tf.y = bh-tf.height;
			s.addChild(tf);
			s.graphics.beginFill(0xFFFFFF, 1);
			s.graphics.drawRect(0, 0, bw, bh);
			s.graphics.endFill();
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
					var picUrl:String = baseUrl + "thumb.php?src="+A[lidx].pic+"&w=100"
					MenuUtils.loadAsset(picUrl,function(pic:Bitmap):void
					{	// create thumbnail of loaded pic
						if (pic == null) pic = new Bitmap(new BitmapData(1, 1, false, 0xFF0000));
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
	// switch between arrow mode and normal mode
	//=============================================================================
	private	var isNormal:Boolean = true;
	public function showNormal():void
	{
		if (isNormal) return;
		isNormal = true;
		trace("showNormal!!");
		sideBtns.visible = true;
		LoadFns[curTab]();
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
	// when icon pressed, returns created image by callback to put onto canvas
	//=============================================================================
	private function mouseDownHandler(ev:Event):void
	{
		// ----- thumbnail pressed
		for (var i:int=0; i<Btns.length; i++)
			if (Btns[i].parent==con && Btns[i].hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
			{
				if (dat[i].dirname != null && dat[i].id != null)	// clicked on folder
				{
					if (dat[i].loadSubFolderFn != null) dat[i].loadSubFolderFn();
				}
				else	// clicked on asset thumb
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
					if (clickCallBack != null)	clickCallBack(img);
				}
			}
		
	}//endfunction
	
	//=============================================================================
	//
	//=============================================================================
	private function mouseUpHandler(ev:Event):void
	{
		// ----- if side button pressed swap category 
		if (sideBtns.visible && sideBtns.hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
			for (var i:int=0; i<sideBtns.numChildren; i++)
				if (sideBtns.getChildAt(i).hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY,true))
					setTabHighlight(i);
		
		// ----- the folder button on top right
		if (btnFolder.hitTestPoint(canvas.stage.mouseX, canvas.stage.mouseY))
		{
			if (curTab == 0)		navigateToURL(new URLRequest(baseUrl+"?n=home&a=tools&c=flash"));
			else if (curTab == 1)	navigateToURL(new URLRequest(baseUrl+"?c=photo&a=designer"));
			else if (curTab == 2)
			{
				if (subCat == "产品收藏") 		navigateToURL(new URLRequest(baseUrl + "??n=home&a=product&c=product"));
				else if (subCat == "搭配收藏") 	navigateToURL(new URLRequest(baseUrl + "??n=home&a=scheme&c=match"));
				else if (subCat == "灵感图收藏") 	navigateToURL(new URLRequest(baseUrl + "??n=home&a=scheme&c=photo"));
			}
		}
		
		// ----- switch page according to page buttons
		var icosPerPage:int = Math.floor((height-marg*2)/(bh+marg))*3;
		var totalPages:int = Math.ceil(Btns.length/icosPerPage);
		if (pageBtns.hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
		{
			for (i=0; i<pageBtns.numChildren; i++)
				if (pageBtns.getChildAt(i).hitTestPoint(canvas.stage.mouseX,canvas.stage.mouseY))
					pageTo(i);
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
		
		while (pageBtns.numChildren > 0) pageBtns.removeChildAt(0);
		for (i=0; i<totalPages; i++)
		{
			var tf:TextField = null;
			if (i==idx)
			{
				tf = PPTool.utils.createText((i + 1) + "", -1, 12, 0xFFFFFF);
				tf.background = true;
				tf.backgroundColor = 0x999999;
			}
			else
				tf = PPTool.utils.createText((i + 1) + "", -1, 12, 0x999999);
			tf.x = i * 20;
			pageBtns.addChild(tf);
		}			
		
		pageBtns.parent.removeChild(pageBtns);
		pageBtns.y = height-pageBtns.height-5;
		pageBtns.x = (canvas.width - pageBtns.width) / 2;
		canvas.addChild(pageBtns);
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
	public var locked:Boolean = false;			// if locked from editing
	
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