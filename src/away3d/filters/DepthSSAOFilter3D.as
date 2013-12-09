package away3d.filters {
	import away3d.cameras.Camera3D;
	import away3d.containers.ObjectContainer3D;
	import away3d.core.managers.Stage3DProxy;
	import away3d.filters.Filter3DBase;

	import flash.geom.Vector3D;

	public class DepthSSAOFilter3D extends Filter3DBase
	{
		private var _task : DepthSSAOFilter3DTask;

		public function DepthSSAOFilter3D()
		{
			super();
			_task = new DepthSSAOFilter3DTask();
			addTask(_task);
		}
		
		public function get contrast() : Number {
			return _task.contrast;
		}

		public function set contrast(value : Number) : void {
			_task.contrast = value;
		}

		public function get range() : Number {
			return _task.range;
		}

		public function set range(value : Number) : void {
			_task.range = value;
		}
		
		public function get r() : Number {
			return _task.r;
		}

		public function set r(value : Number) : void {
			_task.r = value;
		}
		
		public function toggleBlending():void {
			_task.toggleBlending();
		}

	}
}
