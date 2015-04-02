package  {
	
	import flash.display.MovieClip;
	
	
	public class MyButton extends MovieClip {
		
		var originalXScale:Number = -1;
		var originalYScale:Number = -1;
		var originalWidth:Number = -1;
		var originalHeight:Number = -1;
		var originalX:Number = -1;
		var originalY:Number = -1;
		
		public function MyButton() {
			// constructor code
			
		}
		
		public function screenResize(stageX:int, stageY:int, scaleRatio:Number){
			
			//save this movieClip's original scale
			if(this.originalXScale == -1)
			{
				this.originalXScale = this.scaleX;
				this.originalYScale = this.scaleY;
				this.originalX = this.x / 1600;
				this.originalY = this.y / 900;
			}
			
			this.x = stageX * this.originalX;
			this.y = stageY * this.originalY;
    
			//Scale this module/movieClip by the scaleRatio
			this.scaleX = this.originalXScale * scaleRatio;
			this.scaleY = this.originalYScale * scaleRatio;
		}
	}
	
}
