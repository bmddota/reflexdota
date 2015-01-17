package  {
	
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import fl.transitions.Tween;
	import fl.transitions.easing.*;
	import flash.utils.Timer;
	import flash.sampler.NewObjectSample;
	import flash.events.TimerEvent;
	import fl.transitions.TweenEvent;
	
	public class RadiantVictory extends MovieClip {
				
		var gameAPI:Object;
		var globals:Object;
		
		var originalXScale:Number = -1;
		var originalYScale:Number = -1;
		var originalWidth:Number = -1;
		var originalHeight:Number = -1;
		
		public function RadiantVictory() {
			trace("[ReflexUI] RadiantVictory constructed!")
			this.visible = false;
		}
		
		public function setup(api:Object, globals:Object) {
			this.gameAPI = api;
			this.globals = globals;
		}
		
		public function onVictory(kv:Object) {
			if (kv.victor == 2){
				this.visible = true;
				this.alpha = 1;
				
				var timer:Timer = new Timer(2000, 1);
				timer.start();
				timer.addEventListener(TimerEvent.TIMER_COMPLETE, completeHandler);
			}
		}
		
		private function completeHandler(e:TimerEvent):void {
			trace("[ReflexUI] start fade");
			var tween:Tween = new Tween(this, "alpha", null, 1, 0, 1, true)
			tween.start();
			tween.addEventListener(TweenEvent.MOTION_FINISH, tweenFinish);
		}
		
		private function tweenFinish(e:TweenEvent):void {
			trace("fade done");
			this.visible = false;
		}
		
		public function screenResize(stageX:int, stageY:int, scaleRatio:Number){
			//position 'this', being this module, at the center of the screen
			trace("stageX: " + stageX);
			trace("stageY: " + stageY);
			trace("scaleRatio: " + scaleRatio);
			trace("stage.w: " + stage.width);
			trace("stage.h: " + stage.height);
			trace("this.w: " + this.width);
			trace("this.h: " + this.height);
			trace("this.x: " + this.x);
			trace("this.y: " + this.y);
			trace("this.scaleX: " + this.scaleX);
			trace("this.scaleY: " + this.scaleY);
			trace('-----');
			this.x = stageX/2 - this.width/2 * scaleRatio;
			this.y = stageY * .35 - this.height/2 * scaleRatio;
			
			trace("this.x: " + this.x);
			trace("this.y: " + this.y);
			
			//save this movieClip's original scale
			if(this.originalXScale == -1)
			{
				this.originalXScale = this.scaleX;
				this.originalYScale = this.scaleY;
				this.originalWidth = this.width;
				this.originalHeight = this.height;
			}
			
			this.x = stageX/2 - this.originalWidth/2 * scaleRatio;
			this.y = stageY * .35 - this.originalHeight/2 * scaleRatio;
    
			//Scale this module/movieClip by the scaleRatio
			this.scaleX = this.originalXScale * scaleRatio;
			this.scaleY = this.originalYScale * scaleRatio;
		}
	}	
}
