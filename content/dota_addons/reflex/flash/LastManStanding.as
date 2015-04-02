package  {
	
	import flash.display.MovieClip;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	
	
	public class LastManStanding extends MovieClip {
		
		var gameAPI:Object;
		var globals:Object;
		
		var originalXScale:Number = -1;
		var originalYScale:Number = -1;
		var originalWidth:Number = -1;
		var originalHeight:Number = -1;
		
		var startTime:Number = -1;
		var timer:Timer = null;
		
		public function LastManStanding() {
			// constructor code
			this.visible = false;
		}
		
		public function setup(api:Object, globals:Object) {
			this.gameAPI = api;
			this.globals = globals;
			
			this.gameAPI.SubscribeToGameEvent("ref_last_man_standing", this.showAndFade);
		}
		
		public function showAndFade(kv:Object){
			var pID:int = this.globals.Players.GetLocalPlayer();
			if (pID < 0 || pID > 9){
				this.startTime = this.globals.Game.Time();
				this.visible = true;
				
				this.fadeClip.y = 128;
				this.fadeClip.height = 0;
				
				this.timer = new Timer(100, 0);
				this.timer.start();
				this.timer.addEventListener(TimerEvent.TIMER, checkLMS);
			}
		}
		
		private function checkLMS(e:TimerEvent):void {
			if (globals.Loader_overlay.movieClip.dota_paused.visible)
				this.startTime += .1;
			
			var time:Number =  this.globals.Game.Time() - this.startTime;
			
			this.fadeClip.height = time * 128 / 20;
			this.fadeClip.y = 128 - this.fadeClip.height;
			if (time >= 20){
				this.timer.stop();
				this.visible = false;
			}
		}
		
		public function cancelLMS(kv:Object):void {
			if (this.timer != null)
				this.timer.stop();
			this.visible = false;
		}
		
		public function screenResize(stageX:int, stageY:int, scaleRatio:Number){
			
			//save this movieClip's original scale
			if(this.originalXScale == -1)
			{
				this.originalXScale = this.scaleX;
				this.originalYScale = this.scaleY;
				this.originalWidth = this.width;
				this.originalHeight = this.height;
			}
			
			this.x = stageX/2 - this.originalWidth/2 * scaleRatio;
			this.y = stageY * .11 - this.originalHeight/2 * scaleRatio;
    
			//Scale this module/movieClip by the scaleRatio
			this.scaleX = this.originalXScale * scaleRatio;
			this.scaleY = this.originalYScale * scaleRatio;
		}
	}
	
}
