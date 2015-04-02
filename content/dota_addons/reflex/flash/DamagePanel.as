package  {
	
	import flash.display.MovieClip;
	
	
	public class DamagePanel extends MovieClip {
		
		var gameAPI:Object;
		var globals:Object;
		
		var originalXScale:Number = -1;
		var originalYScale:Number = -1;
		var originalWidth:Number = -1;
		var originalHeight:Number = -1;
		
		var playerDamage:Object = null;
		var pTotals:String = null;
		var pLasts:String = null;
		
		public function DamagePanel() {
			// constructor code
			this.dpdEx.visible = false;
			this.visible = false;
		}
		
		public function togglePanel(){
			if (this.visible)
				this.visible = false;
			else {
				this.visible = true;
				if (playerDamage == null)
					buildPanel();
					if (pTotals != null)
						OnDamageUpdate({totals:pTotals});
					if (pLasts != null)
						OnLastRoundUpdate({lasts:pLasts});
				else{
					var i:int;
					for (i = 0; i < 5; i++){
						var rpd:RadiantPlayerDamage = playerDamage[i];
						if (rpd != null){
							rpd.nameText.text = globals.Players.GetPlayerName(i);
							globals.LoadHeroImage(globals.Players.GetPlayerSelectedHero(i).replace('npc_dota_hero_', ''), rpd.heroPortrait);
						}
					}
					for (i = 5; i < 10; i++){
						var dpd:DirePlayerDamage = playerDamage[i];
						if (dpd != null){
							dpd.nameText.text = globals.Players.GetPlayerName(i);
							globals.LoadHeroImage(globals.Players.GetPlayerSelectedHero(i).replace('npc_dota_hero_', ''), dpd.heroPortrait);
						}
					}
				}
			}
		}
		
		public function buildPanel(){
			playerDamage = new Object();
			var pID:int = globals.Players.GetLocalPlayer();
			trace("player: " + pID);
			
			var curY:int = 40;
			var i:int = 0;
			var color:uint = 0;
			
			if (pID >= 5 && pID <= 9){
				// Dire
				for (i = 5; i < 10; i++){
					if (globals.Players.IsValidPlayer(i)){
						var pd:DirePlayerDamage = new DirePlayerDamage();
						pd.x = 13;
						pd.y = curY;
						pd.nameText.text = globals.Players.GetPlayerName(i);
						color = globals.Players.GetPlayerColor(i) - 0xFF000000;
						color = ((color % 0x100) << 16) + (((color % 0x10000) / 0x100) << 8) + ((color % 0x1000000) / 0x10000);
						pd.nameText.textColor = color;
						pd.lastRound.text = "0";
						pd.total.text = "0";
						globals.LoadHeroImage(globals.Players.GetPlayerSelectedHero(i).replace('npc_dota_hero_', ''), pd.heroPortrait);
						pd.heroPortrait.scaleX = 56 * pd.heroPortrait.scaleX/pd.heroPortrait.width;
						pd.heroPortrait.scaleY = 30 * pd.heroPortrait.scaleY/pd.heroPortrait.height;
						
						addChild(pd);
						playerDamage[i] = pd;
						curY += pd.height + 5;
					}
				}
			}
			else{
				// Radiant
				for (i = 0; i < 5; i++){
					if (globals.Players.IsValidPlayer(i)){
						var rpd:RadiantPlayerDamage = new RadiantPlayerDamage();
						rpd.x = 13;
						rpd.y = curY;
						rpd.nameText.text = globals.Players.GetPlayerName(i);
						color = globals.Players.GetPlayerColor(i) - 0xFF000000;
						color = ((color % 0x100) << 16) + (((color % 0x10000) >> 8) << 8) + ((color % 0x1000000) >> 16);
						rpd.nameText.textColor = color;
						rpd.lastRound.text = "0";
						rpd.total.text = "0";
						globals.LoadHeroImage(globals.Players.GetPlayerSelectedHero(i).replace('npc_dota_hero_', ''), rpd.heroPortrait);
						rpd.heroPortrait.scaleX = 56 * rpd.heroPortrait.scaleX/rpd.heroPortrait.width;
						rpd.heroPortrait.scaleY = 30 * rpd.heroPortrait.scaleY/rpd.heroPortrait.height;
						
						addChild(rpd);
						playerDamage[i] = rpd;
						curY += rpd.height + 5;
					}
				}
			}
			
			if (pID < 0 || pID > 9){
				// Spectator/Broadcaster
				curY += 20;
				for (i = 5; i < 10; i++){
					if (globals.Players.IsValidPlayer(i)){
						var dpd:DirePlayerDamage = new DirePlayerDamage();
						dpd.x = 13;
						dpd.y = curY;
						dpd.nameText.text = globals.Players.GetPlayerName(i);
						color = globals.Players.GetPlayerColor(i) - 0xFF000000;
						color = ((color % 0x100) << 16) + (((color % 0x10000) / 0x100) << 8) + ((color % 0x1000000) / 0x10000);
						dpd.nameText.textColor = color;
						dpd.lastRound.text = "0";
						dpd.total.text = "0";
						globals.LoadHeroImage(globals.Players.GetPlayerSelectedHero(i).replace('npc_dota_hero_', ''), dpd.heroPortrait);
						dpd.heroPortrait.scaleX = 56 * dpd.heroPortrait.scaleX/dpd.heroPortrait.width;
						dpd.heroPortrait.scaleY = 30 * dpd.heroPortrait.scaleY/dpd.heroPortrait.height;
						
						addChild(dpd);
						playerDamage[i] = dpd;
						curY += dpd.height + 5;
					}
				}
			}
			
			trace(this.bgImage.scaleY);
			trace(this.bgImage.height);
			trace(curY + 20);
			this.bgImage.scaleY = (curY + 20) * this.bgImage.scaleY / this.bgImage.height;
		}
		
		public function setup(api:Object, globals:Object){
			this.gameAPI = api;
			this.globals = globals;
			
			gameAPI.SubscribeToGameEvent("ref_damage_update", this.OnDamageUpdate);
			gameAPI.SubscribeToGameEvent("ref_lr_damage_update", this.OnLastRoundUpdate);
			
			/*trace("DAMAGEPANEL");
			var rpd:RadiantPlayerDamage = new RadiantPlayerDamage();
			var dpd:DirePlayerDamage = new DirePlayerDamage();
			rpd.x = 13;
			rpd.y = 40;
			rpd.nameText.text = "ASASF";
			rpd.lastRound.text = "11111";
			rpd.total.text = "33333";
			globals.LoadHeroImage("axe", rpd.heroPortrait);
			trace(rpd.heroPortrait.width);
			trace(rpd.heroPortrait.height);
			trace(rpd.heroPortrait.scaleX);
			trace(rpd.heroPortrait.scaleY);
			trace("A---------A");
			rpd.heroPortrait.scaleX = 56 * rpd.heroPortrait.scaleX/rpd.heroPortrait.width;
			rpd.heroPortrait.scaleY = 30 * rpd.heroPortrait.scaleY/rpd.heroPortrait.height;
			trace(rpd.heroPortrait.scaleX);
			trace(rpd.heroPortrait.scaleY);
			trace("A----AB");
			addChild(rpd);
			
			dpd.x = 13;
			dpd.y = rpd.height + 5 + rpd.y;
			dpd.nameText.text = "DDDDDD";
			dpd.lastRound.text = "222";
			dpd.total.text = "44444";
			addChild(dpd);*/
		}
		
		private function OnDamageUpdate(kv:Object){
			pTotals = kv.totals;
			var totals:Array = kv.totals.split(",");
			var i:int = 0;
			
			if (playerDamage != null){
				for (i = 0; i<5; i++){
					var rpd:RadiantPlayerDamage = playerDamage[i];
					if (rpd != null)
						rpd.total.text = totals[i];
				}
				
				for (i = 5; i<10; i++){
					var dpd:DirePlayerDamage = playerDamage[i];
					if (dpd != null)
						dpd.total.text = totals[i];
				}
			}
		}
		
		private function OnLastRoundUpdate(kv:Object){
			pLasts = kv.lasts;
			var lasts:Array = kv.lasts.split(",");
			var i:int = 0;
			
			if (playerDamage != null){
				for (i = 0; i<5; i++){
					var rpd:RadiantPlayerDamage = playerDamage[i];
					if (rpd != null)
						rpd.lastRound.text = lasts[i];
				}
				
				for (i = 5; i<10; i++){
					var dpd:DirePlayerDamage = playerDamage[i];
					if (dpd != null)
						dpd.lastRound.text = lasts[i];
				}
			}
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
			
			//this.x = stageX/2 - this.originalWidth/2 * scaleRatio;
			//this.y = stageY * .35 - this.originalHeight/2 * scaleRatio;
    
			//Scale this module/movieClip by the scaleRatio
			this.scaleX = this.originalXScale * scaleRatio;
			this.scaleY = this.originalYScale * scaleRatio;
		}
	}
	
}
