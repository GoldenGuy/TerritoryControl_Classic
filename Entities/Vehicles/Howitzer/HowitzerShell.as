#include "Hitters.as";
#include "Explosion.as";

void onInit(CBlob@ this)
{
	this.server_SetTimeToDie(20);
	
	this.getShape().getConsts().mapCollisions = false;
	this.getShape().getConsts().bullet = true;
	this.getShape().getConsts().net_threshold_multiplier = 4.0f;
	
	this.Tag("projectile");
	
	this.set_Vec2f("initial position", this.getPosition());

	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);
	this.sendonlyvisible = false;
	
	//CPlayer@ local = getLocalPlayer();
	//if (local !is null && (local.getTeamNum() == this.getTeamNum() || local is this.getDamageOwnerPlayer()))
	{
		this.SetMinimapOutsideBehaviour(CBlob::minimap_arrow);
		this.SetMinimapVars("GUI/Minimap/MinimapIcons.png", 1, Vec2f(16, 16));
		this.SetMinimapRenderAlways(true);
	}
	
	CSprite@ sprite = this.getSprite();
	sprite.getConsts().accurateLighting = false;
	sprite.SetEmitSound("Shell_Whistle.ogg");
	sprite.SetEmitSoundPaused(false);
	sprite.SetEmitSoundVolume(0.0f);
	sprite.SetEmitSoundSpeed(0.9f);
}

void onTick(CBlob@ this)
{
	Vec2f velocity = this.getVelocity();
	const f32 angle = velocity.Angle();
	this.setAngleDegrees(-angle);
	
	const f32 modifier = Maths::Max(0, velocity.y * 0.02f);
	this.getSprite().SetEmitSoundVolume(Maths::Max(0, modifier));
	
	if (isServer())
	{
		Vec2f end;
		if (getMap().rayCastSolidNoBlobs(this.getOldPosition(), this.getPosition(), end))
		{
			//this.setPosition(end);
			this.server_Die();
		}
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (!isServer()) return;

	if (blob is null) return;

	if (blob.isPlatform() && !solid) return;

	if (blob.hasTag("no pickup") && blob.get_u8("bomber team") == this.getTeamNum()) return; //do not kill our own bomber's bombs

	if (doesCollideWithBlob(this, blob))
	{
		this.server_Die();
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	const bool willExplode = this.getTeamNum() == blob.getTeamNum() ? blob.getShape().isStatic() : true; 
	if (blob.isCollidable() && willExplode)
	{
		CPlayer@ player = blob.getPlayer();
		if (player !is null && player is this.getDamageOwnerPlayer()) return false;

		return true;
	}
	return false;
}

void onDie(CBlob@ this)
{
	DoExplosion(this);
}

void DoExplosion(CBlob@ this)
{
	if (this.hasTag("dead")) return;
	this.Tag("dead");

	this.SetMinimapRenderAlways(false);
	
	Vec2f velocity = this.getOldVelocity();

	Random rand(this.getNetworkID());
	Explode(this, 64.0f, 4.0f);
	for (int i = 0; i < 4; i++)
	{
		Vec2f jitter = Vec2f((int(rand.NextRanged(200)) - 100) / 200.0f, (int(rand.NextRanged(200)) - 100) / 200.0f);
		LinearExplosion(this, Vec2f(velocity.x * jitter.x, velocity.y * jitter.y), 32.0f + rand.NextRanged(32), 24.0f, 4, 10.0f, Hitters::explosion);
	}

	this.getSprite().Gib();
}
