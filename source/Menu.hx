package;

import flixel.*;
import flixel.FlxBasic.FlxType;
import flixel.addons.display.FlxBackdrop;
import flixel.effects.FlxFlicker;
import flixel.effects.particles.FlxEmitter;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.input.keyboard.FlxKeyboard;
import flixel.util.FlxSave;

/*
	sfx needed
	start game S
	lose D
	drop piece D
	match D
	win
 */
class Menu extends FlxState
{
	var backdrop:FlxBackdrop;
	var titleimage:FlxSprite;
	var promptimage:FlxSprite;

	public static var playingendmusic:Bool = false;

	override public function create()
	{
		super.create();

		// if not playing music
		if (FlxG.sound.music == null || FlxG.sound.music.playing == false || playingendmusic)
		{
			FlxG.sound.playMusic(AssetPaths.music__ogg, 0.5, true);
		}

		backdrop = new FlxBackdrop("assets/images/titlebg.png");
		backdrop.velocity.x = 5;
		backdrop.velocity.y = 5;
		add(backdrop);

		titleimage = new FlxSprite(0, 0, "assets/images/titlefg.png");
		add(titleimage);

		promptimage = new FlxSprite(0, 0, "assets/images/titleprompt.png");
		add(promptimage);
	}

	var time:Float;

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		time += elapsed;

		// wobble titleimage over time sinusodially
		titleimage.angle = Math.sin(time / 10) * 5;

		if (FlxG.keys.justPressed.X || FlxG.keys.justPressed.C)
		{
			FlxG.sound.play(AssetPaths.start__ogg);
			// flicker prompt sprite
			FlxFlicker.flicker(promptimage, 1, 0.1, null, true, loadGame);
		}
	}

	private function loadGame(a:FlxFlicker)
	{
		FlxG.switchState(new PlayState());
	}
}
