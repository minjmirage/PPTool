package {

	import flash.display.Stage;
	import flash.display.Loader;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.net.URLRequest;

	[SWF(width = "800", height = "600", frameRate = "30")];
		
	public class Preloader extends Sprite 
	{
		public var ldr:Loader = null;
		public var baseUrl:String = "http://ruanzhuangyun.cn/";// "http://symspace.e360.cn/";
		public var userToken:String = null;
		
		//
		//
		//
		public function Preloader():void
		{
			trace("??? stage="+stage);
			stage.scaleMode = "noScale";
			stage.align = "topLeft";
			
			if (root.loaderInfo.parameters.httpURL!=null) baseUrl = root.loaderInfo.parameters.httpURL+"";	// why the F$%$ this doesnt work
			if (root.loaderInfo.parameters.token!=null) userToken = root.loaderInfo.parameters.token+"";
			if (baseUrl.charAt(baseUrl.length - 1) != "/")	baseUrl += "/";
			
			ldr = new Loader();             			// create a new instance of the Loader class
			ldr.load(new URLRequest("PPTool.swf")); 	// in this case both SWFs are in the same folder 
			
			var tf:TextField = new TextField();
			tf.autoSize = "left";
			tf.wordWrap = false;
			var tff:TextFormat = tf.defaultTextFormat;
			tff.font = "arial bold";
			tff.size = 30;
			tf.defaultTextFormat = tff;
			tf.text = "0";
			
			var prog:int = 0;
			var ppp:Sprite = this;
			function enterFrameHandler(e:Event):void 
			{
				var sw:int = stage.stageWidth;
				var sh:int = stage.stageHeight;
				
				var r:Number = 0;
				if (ldr.contentLoaderInfo!=null)
					r = ldr.contentLoaderInfo.bytesLoaded / ldr.contentLoaderInfo.bytesTotal;
				
				if (prog< Math.round(r*100))	prog++;
				
				// ----- draw loading circle
				ppp.graphics.clear();
				ppp.graphics.beginFill(0x99AAFF, 1);
				ppp.graphics.moveTo(sw/2,sh/2-100);
				for (var i:int = 0; i <= prog/100*360; i++)
					ppp.graphics.lineTo(sw/2+Math.sin(i/180*Math.PI)*100, sh/2-Math.cos(i/180*Math.PI)*100);
				for (; i>=0; i--)
					ppp.graphics.lineTo(sw/2+Math.sin(i/180*Math.PI)*90, sh/2-Math.cos(i/180*Math.PI)*90);
				ppp.graphics.endFill();
				
				tf.text = prog+"";
				tf.x = (sw - tf.width) / 2;
				tf.y = (sh - tf.height) / 2;
				addChild(tf);
				
				if (prog == 100 && ldr.content!=null)
				{
					stage.removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
					addChild(ldr.content);
				}
			}
			
			stage.addEventListener(Event.ENTER_FRAME, enterFrameHandler);
			
		}//endfunction
	}//endclass
}