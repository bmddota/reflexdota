package {
	import flash.display.MovieClip;

	//import some stuff from the valve lib
	import ValveLib.Globals;
	import ValveLib.ResizeManager;
	import flash.events.MouseEvent;
	import scaleform.clik.events.ButtonEvent;
	import flash.utils.getDefinitionByName;
	import flash.utils.describeType;
	import flash.geom.Point;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import ValveLib.Events.InputBoxEvent;
	import scaleform.clik.managers.InputDelegate;
	import scaleform.clik.events.InputEvent;
	import scaleform.clik.ui.InputDetails;
	import scaleform.gfx.InteractiveObjectEx;
	import scaleform.clik.core.CLIK;
	import scaleform.clik.core.UIComponent;
	import scaleform.clik.utils.GameCenterInterface;
	import scaleform.gfx.KeyboardEventEx;
	import flash.events.KeyboardEvent;
	import flash.events.EventDispatcher;
	
	public class ReflexUI extends MovieClip{
		
		//these three variables are required by the engine
		public var gameAPI:Object;
		public var globals:Object;
		public var elementName:String;
		
		private var damageButton:MovieClip = null;
		private var dashClips:Object = new Object();
		private var dashTimer:Timer = null;
		
		private var abilityClips:Object = new Object();
		private var itemAbilityClips:Object = new Object();
		private var currentAbilities:Array = new Array();
		private var abilitiesTimer:Timer = null;
		
		private var asdf:Boolean = false;
		private var origScaleX:Number = -1;
		private var origScaleY:Number = -1;
		
		private var origChatY:Number = -1;
		private var moveChat:Boolean = false;
		private var abilityIcons:Array = new Array();
		private var itemAbilityIcons:Array = new Array();

		private var colorToID:Object = {
			4294931763:0,
			4290772838:1,
			4290707647:2,
			4278972659:3,
			4278217727:4,
			4290938622:5,
			4282889377:6,
			4294433125:7,
			4280386304:8,
			4278217124:9}
		
		//constructor, you usually will use onLoaded() instead
		public function ReflexUI() : void {
			trace("[ReflexUI] Reflex UI Constructed!");
			
			for (var i:int = 0; i < 10; i++){
				var dc:DashCount = new DashCount();
				dc.width = 40;
				dc.height = 40;
				
				addChildAt(dc, 0);
				dc.visible = false;
				dashClips[i] = dc;
			}
			
			this.exDash.visible = false;
			
			this.origScaleX = dashClips[0].scaleX;
			this.origScaleY = dashClips[0].scaleY;
		}
		
		//this function is called when the UI is loaded
		public function onLoaded() : void {			
			//make this UI visible
			visible = true;
			var pID:int = this.globals.Players.GetLocalPlayer();
			
			//let the client rescale the UI
			Globals.instance.resizeManager.AddListener(this);
			
			//this is not needed, but it shows you your UI has loaded (needs 'scaleform_spew 1' in console)
			trace("[ReflexUI] Reflex UI loaded!");
			trace("[ReflexUI] BUILD: 1000000022");
			
			//pass the gameAPI on to the module
			this.radiantVictory.setup(this.gameAPI, this.globals);
			this.direVictory.setup(this.gameAPI, this.globals);
			this.damagePanel.setup(this.gameAPI, this.globals);
			this.lastManStanding.setup(this.gameAPI, this.globals);
			//this.testButton.addEventListener(MouseEvent.CLICK, onButtonClicked);
			
			damageButton.addEventListener(ButtonEvent.CLICK, onButtonClicked, false,0, true);
			
			this.origChatY = globals.Loader_hud_chat.movieClip.y;
			
			var oldChatSay:Function = globals.Loader_hud_chat.movieClip.gameAPI.ChatSay;
			globals.Loader_hud_chat.movieClip.gameAPI.ChatSay = function(obj:Object, bool:Boolean){
				gameAPI.SendServerCommand( "player_say " + obj.toString());
				oldChatSay(obj, bool);
			};

			scoreboardPatch();
			abilitiesTimer = new Timer(2000, 0);
			abilitiesTimer.addEventListener(TimerEvent.TIMER, abilitiesUpdate);
			abilitiesTimer.start();
			
			dashTimer = new Timer(200, 0);
			if (pID < 0 || pID > 9){
				dashTimer.start();
				dashTimer.addEventListener(TimerEvent.TIMER, dashUpdate);
			}
			
			this.gameAPI.SubscribeToGameEvent("ref_round_complete", this.onRoundComplete);
			trace("setting camera distance");
			Globals.instance.GameInterface.SetConvar("dota_camera_distance", "1504");
		}
		
		private function abilitiesUpdate(event:TimerEvent):void{
			var pID:int = this.globals.Players.GetLocalPlayer();
			
			var i:int = 0;
			var j:int = 0;
			var playerID:int =  0;
			var entIndex:int;
			var abilityID:Number;
			var abilityName:String;
			var texture:String;
			var ab:MovieClip;
			
			for (i = 0; i<10; i++){
				abilityIcons[i].visible = false;
				itemAbilityIcons[i].visible = false;
			}
			
			// radiant/spec
			if (pID < 5 || pID > 9){
				for (i=0; i<5; i++){
					playerID = colorToID[globals.Players.GetPlayerColor(i)];
					entIndex =  globals.Players.GetPlayerHeroEntityIndex(i);
					
					if (entIndex != -1 && colorToID[globals.Players.GetPlayerColor(i)] != undefined){
						abilityIcons[playerID].visible = true;
						itemAbilityIcons[playerID].visible = true;
						for (j=0; j<6; j++){
							abilityID = globals.Entities.GetAbility(entIndex, j);

							// Ensure a valid ability
							if(abilityID == -1 || globals.Abilities.IsHidden(abilityID)) continue;

							// Print out the name
							abilityName = globals.Abilities.GetAbilityName(abilityID);
							
							if (currentAbilities[playerID][j] == abilityName) continue;
							
							texture = globals.Abilities.GetAbilityTextureName(abilityID);
							
							ab = abilityIcon(abilityIcons[playerID], abilityName, texture);
							ab.scaleX = 64/256;
							ab.scaleY = 64/256;
							ab.x = j*ab.width*0.5;
							ab.y = 0;
							
							abilityIcons[playerID].removeChild(abilityClips[i][j]);
							abilityClips[i][j] = ab;
							
							ab = abilityIcon(itemAbilityIcons[playerID], abilityName, texture);
							ab.scaleX = 40/256;
							ab.scaleY = 40/256;
							ab.x = j*ab.width*0.5;
							ab.y = -2;
							
							itemAbilityIcons[playerID].removeChild(itemAbilityClips[i][j]);
							itemAbilityClips[i][j] = ab;
							
							currentAbilities[playerID][j] = abilityName;
						}
					}
				}
			}
			
			// dire/spec
			if (pID < 0 || pID > 4){
				for (i=5; i<10; i++){
					playerID = colorToID[globals.Players.GetPlayerColor(i)];
					entIndex =  globals.Players.GetPlayerHeroEntityIndex(i);
					
					if (entIndex != -1 && colorToID[globals.Players.GetPlayerColor(i)] != undefined){
						abilityIcons[playerID].visible = true;
						itemAbilityIcons[playerID].visible = true;
						for (j=0; j<6; j++){
							abilityID = globals.Entities.GetAbility(entIndex, j);

							// Ensure a valid ability
							if(abilityID == -1 || globals.Abilities.IsHidden(abilityID)) continue;

							// Print out the name
							abilityName = globals.Abilities.GetAbilityName(abilityID);
							
							if (currentAbilities[playerID][j] == abilityName) continue;
							
							texture = globals.Abilities.GetAbilityTextureName(abilityID);
							
							ab = abilityIcon(abilityIcons[playerID], abilityName, texture);
							ab.scaleX = 64/256;
							ab.scaleY = 64/256;
							ab.x = j*ab.width*0.5;
							ab.y = 0;
							
							abilityIcons[playerID].removeChild(abilityClips[i][j]);
							abilityClips[i][j] = ab;
							
							ab = abilityIcon(itemAbilityIcons[playerID], abilityName, texture);
							ab.scaleX = 40/256;
							ab.scaleY = 40/256;
							ab.x = j*ab.width*0.5;
							ab.y = -2;
							
							itemAbilityIcons[playerID].removeChild(itemAbilityClips[i][j]);
							itemAbilityClips[i][j] = ab;
							
							currentAbilities[playerID][j] = abilityName;
						}
					}
				}
			}
		}
		
		// Patches the scoreboard
		private function scoreboardPatch():void {
			var i;
			// Grab the scoreboard
			var scoreboard:MovieClip = globals.Loader_scoreboard.movieClip.scoreboard.scoreboard_anim;
			var itemsboard:MovieClip = globals.Loader_spectator_items.movieClip.board_items.Board_Items_anim;

			for(i=0; i<10; ++i) {
				var newCon:MovieClip = new MovieClip();
				abilityIcons[i] = newCon;
				var con:MovieClip = scoreboard['Player' + i];
				con.addChild(newCon);
				newCon.x = 768/2 - 80;//scoreboard.width;
				abilityClips[i] = new Array();
				
				newCon = new MovieClip();
				itemAbilityIcons[i] = newCon;
				con = itemsboard['items' + i];
				con.addChild(newCon);
				newCon.x = con.stashBG.x;
				itemAbilityClips[i] = new Array();
				
				con.stashBG.enabled = false;
				con.stashBG.visible = false;
				
				for (var k:int=7; k<=12; k++){
					con['Item' + k].enabled = false;
					con['Item' + k].visible = false;
				}
				
				currentAbilities[i] = new Array();
				
				for (var j:int=0; j<6; j++){
					currentAbilities[i][j] = "reflex_empty" + (j+1);
					
					var ab:MovieClip = abilityIcon(abilityIcons[i], currentAbilities[i][j], "rubick_empty1");
					ab.scaleX = 64/256;
					ab.scaleY = 64/256;
					ab.x = j*ab.width*0.5;
					ab.y = 0;
					
					abilityClips[i][j] = ab;
					
					ab = abilityIcon(itemAbilityIcons[i], currentAbilities[i][j], "rubick_empty1");
					ab.scaleX = 40/256;
					ab.scaleY = 40/256;
					ab.x = j*ab.width*0.5;
					ab.y = -2;
					
					itemAbilityClips[i][j] = ab;
				}
			}

			//var inject:MovieClip = new backgroundMask();

			//scoreboard.addChild(inject);
		}
		
		private function onRoundComplete(kv:Object){
			this.radiantVictory.onVictory(kv);
			this.direVictory.onVictory(kv);
			this.lastManStanding.cancelLMS(kv);
		}
		
		private function dashUpdate(event:TimerEvent) : void {
			var pID:int = this.globals.Players.GetLocalPlayer();
			var i:int = 0;
			var dc:DashCount;
			if (pID >= 0 && pID <= 9){
				dashTimer.stop();
				for (i = 0; i < 10; i++){
					dc = dashClips[i];
					dc.visible = false;
				}
				
				if (moveChat){
					globals.Loader_hud_chat.movieClip.y = 0;
					globals.Loader_hud_chat.movieClip.hud_chat_input.y += 80;
					globals.Loader_hud_chat.movieClip.hud_events.y += 80;
					globals.Loader_hud_chat.movieClip.hud_chat.y += 80;
				}
			}
			
			for (i = 0; i < 10; i++){
				var playerID:int = colorToID[globals.Players.GetPlayerColor(i)];
				
				var entIndex:Object = globals.Players.GetPlayerHeroEntityIndex(i);
				//trace("entIndex: " + entIndex);
				if (entIndex != -1 && colorToID[globals.Players.GetPlayerColor(i)] != undefined){
					if (globals.Entities.GetHealth(entIndex) <= 0){
						dashClips[playerID].visible = false;
					}else{
						for (var j:int = 0; j <= 11; j++){
							var item:Object = globals.Entities.GetItemInSlot(entIndex, j);
							var iname:String = globals.Abilities.GetAbilityName(item);
							//trace(j + ": " + iname);
							if (iname.indexOf("item_reflex_dash") == 0){
								var charges:int = globals.Items.GetCurrentCharges(item);
								//trace("charges: " + charges);
								dashClips[playerID].visible = true;
								dashClips[playerID].count.text = charges.toString();
								switch(charges){
									case 0:
										dashClips[playerID].count.textColor = 0xFF0000;
										break;
									case 1:
										dashClips[playerID].count.textColor = 0xFF6633;
										break;
									default:
										dashClips[playerID].count.textColor = 0xFFFFFF;
										break;
								}
							}
						}
					}
					//trace("=============");
				}
			}
		}
		
		private function onButtonClicked(event:ButtonEvent) : void {
			trace("button clicked");
			this.damagePanel.togglePanel();
			
			/*this.lastManStanding.showAndFade();
			
			this.asdf = ! asdf;
			if (this.asdf)
				this.radiantVictory.onVictory();
			else
				this.direVictory.onVictory();*/
		}
		
		//this handles the resizes - credits to Nullscope
		public function onResize(re:ResizeManager) : * {
			var pID:int = this.globals.Players.GetLocalPlayer();
			var rm = Globals.instance.resizeManager;
			var currentRatio:Number =  re.ScreenWidth / re.ScreenHeight;
			var divided:Number;
		
			// Set this to your stage height, however, if your assets are too big/small for 1024x768, you can change it
			// This is just your original stage height
			var originalHeight:Number = 900;
					
			if(currentRatio < 1.5)
			{
				// 4:3
				divided = currentRatio * 3 / 4.0;
			}
			else if(re.Is16by9()){
				// 16:9
				divided = currentRatio * 9 / 16.0;
			} else {
				// 16:10
				divided = currentRatio * 10 / 16.0;
			}
							
			 var correctedRatio:Number =  re.ScreenHeight / originalHeight * divided;
			
			//pass the resize event to our module, we pass the width and height of the screen, as well as the correctedRatio.
			trace("[ReflexUI] onResize");
			this.radiantVictory.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			this.direVictory.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			this.testButton.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			this.damagePanel.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			this.lastManStanding.screenResize(re.ScreenWidth, re.ScreenHeight, correctedRatio);
			trace("[ReflexUI] onResize2");
			
			
			//globals.Loader_hud_chat.movieClip.SetHeaderFirstBloodPosition(new Point(800, 400));
			//globals.Loader_hud_chat.movieClip.SetHeaderMultikillPosition(new Point(800, 400));
			//globals.Loader_hud_chat.movieClip.SetHeaderCalloutPosition(new Point(800, 400));
			
			trace("clipY: " + globals.Loader_hud_chat.movieClip.y);
			trace("clipScaleY: " + globals.Loader_hud_chat.movieClip.scaleY);
			trace("inputY: " + globals.Loader_hud_chat.movieClip.hud_chat_input.y);
			
			if (pID < 0 || pID > 9){
				globals.Loader_hud_chat.movieClip.y = 80 * correctedRatio;
				globals.Loader_hud_chat.movieClip.hud_chat_input.y -= 80;
				globals.Loader_hud_chat.movieClip.hud_events.y -= 80;
				globals.Loader_hud_chat.movieClip.hud_chat.y -= 80;
				moveChat = true;
			}
			
			var sc:MovieClip = globals.Loader_scoreboard.movieClip.menuButtons.shareUnitsButton;
			trace(sc.x);
			trace(sc.y);
			trace(sc.width);
			trace(sc.height);
			var point:Point = sc.localToGlobal(new Point(sc.x, sc.y));
			trace(point.x);
			trace(point.y);
			trace("----");
			
			if (damageButton == null) {
				damageButton = replaceWithValveComponent(this.testButton, "ButtonSkinned")
				damageButton.label = "Damage";
				damageButton.enabled = true;
				damageButton.width = 60;
			}
			damageButton.x = point.x + (sc.width + 8) * correctedRatio;
			damageButton.y = point.y + 5 * correctedRatio;
			
			
			for (var i:int = 0; i < 10; i++){
				sc = globals.Loader_scoreboard.movieClip.topbar["s_player" + i + "_hero_portrait"].heroPortrait;
				point = sc.localToGlobal(new Point(sc.x, sc.y));
				
				dashClips[i].x = point.x + 6 * correctedRatio;
				dashClips[i].y = point.y + 40 * correctedRatio;
				dashClips[i].scaleX = this.origScaleX * correctedRatio;
				dashClips[i].scaleY = this.origScaleY * correctedRatio;
			}
		}
		
		public function abilityIcon(container:MovieClip, ability:String, texture:String):MovieClip {
            // Create it
            var obj:MovieClip = new DotaAbility(ability);//new dotoClass();
            container.addChild(obj);

            // Add image
            globals.LoadAbilityImage(texture, obj.ability.AbilityArt);

            // Add the cover command
            obj.addEventListener(MouseEvent.ROLL_OVER, onSkillRollOver, false, 0, true);
            obj.addEventListener(MouseEvent.ROLL_OUT, onSkillRollOut, false, 0, true);

            // Return the button
            return obj;
        }

        // When someone hovers over a skill
        private function onSkillRollOver(e:MouseEvent):void {
            // Don't show stuff if we're dragging
            //if(EasyDrag.isDragging()) return;

            // Grab what we rolled over
            var s:Object = e.target;

            // Workout where to put it
            var lp:Point = s.localToGlobal(new Point(s.width*0.125*0.5, 0));

            var offset = 0;
            if(lp.x < stage.stageWidth/2) {
                offset = s.width*2;
            }

            // Workout where to put it
            lp = s.localToGlobal(new Point(offset, 0));

            // Decide how to show the info
            if(lp.x < stage.stageWidth/2) {
                // Face to the right
                globals.Loader_rad_mode_panel.gameAPI.OnShowAbilityTooltip(lp.x, lp.y, s.skillName);
            } else {
                // Face to the left
                globals.Loader_heroselection.gameAPI.OnSkillRollOver(lp.x, lp.y, s.skillName);
            }
        }

        // When someone stops hovering over a skill
        private function onSkillRollOut(e:MouseEvent):void {
            // Hide the skill info pain
            globals.Loader_heroselection.gameAPI.OnSkillRollOut();
        }
		 
		//mc - The movieclip to replace
		//type - The name of the class you want to replace with
		//keepDimensions - Resize from default dimensions to the dimensions of mc (optional, false by default)
		public function replaceWithValveComponent(mc:MovieClip, type:String, keepDimensions:Boolean = false) : MovieClip {
			var parent = mc.parent;
			var oldx = mc.x;
			var oldy = mc.y;
			var oldwidth = mc.width;
			var oldheight = mc.height;
			
			var newObjectClass = getDefinitionByName(type);
			var newObject = new newObjectClass();
			newObject.x = oldx;
			newObject.y = oldy;
			if (keepDimensions) {
				newObject.width = oldwidth;
				newObject.height = oldheight;
			}
			
			parent.removeChild(mc);
			parent.addChild(newObject);
			
			return newObject;
		}
	}
}