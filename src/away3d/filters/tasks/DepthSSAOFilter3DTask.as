package away3d.filters.tasks
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.Stage3DProxy;
	import away3d.filters.tasks.Filter3DTaskBase;
	
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.textures.Texture;

	use namespace arcane;

	public class DepthSSAOFilter3DTask extends Filter3DTaskBase
	{
		private var _data : Vector.<Number>;

		private var _r:Number = 0.0025;
		private var _numPasses:uint = 8;
		
		private var _range:Number = 1000;
		private var _contrast:Number = 10.0;
		private var _blending:uint = 0;
		
		public function DepthSSAOFilter3DTask()
		{
			super(true);
			_data = Vector.<Number>([_r, 1 / _numPasses, 0, 0.1, // fc0[x,y,z,w]
									0, 0, 0, 0, // fc1[x,y,z,w]
									_range, 0, 0, 0, // fc2[x,y,z,w]
									1.0, 1 / 255.0, 1 / 65025.0, 1 / 16581375.0, // fc3[x,y,z,w] -> ARGB
									1.0, 1.0, 1.0, 1.0, // fc4[x,y,z,w] solid color
									_contrast, 4.0, 0.2, 0.1, // fc5[x,y,z,w] contrast, r, bleed, brightness
									0.0, 0.0, 1.0, 0.1 // fc6[x,y,z,w] a screen normal (N)
									]); 
		}

		override protected function getFragmentCode() : String
		{
			var code : String;
			
			code = "tex ft0, v0, fs1 <2d,nearest,repeat>	\n"; // sample depth map (ft0)
			code += "dp4 ft1.z, ft0, fc3 	\n"; // unpack depth map (ft1.z)
			
			code += "sub ft1.z, ft1.z, fc1.z   \n" + // d = d - f
					"div ft1.z, fc1.w, ft1.z   \n" + // screenZ = -n*f/(d-f)
					"div ft1.z, ft1.z, fc2.x   \n" + // (screenZ - dist)/range
					"abs ft1.z, ft1.z     \n" + // abs(screenZ - dist)/range
					"sat ft1.z, ft1.z     \n";	// sat(abs(screenZ - dist)/range)
			code += "sub ft1.z, fc3.x, ft1.z   \n"; // depth = 1 - depth, (z0 = ft1.z)
			
			// set the initial value
			code += "mov ft6, fc6.xxxx	\n"; // zeros
			
			/*// threshold - a simple implementation of "if" condition
			code += "sge ft1.x, ft1.z, fc6.w 	\n" +	// ft1.x = (z > fc6.w) ? 1 : 0 
					"mul ft1.z, ft1.z, ft1.x	\n";	// z = z * ft1.x*/
			
			//code += "add ft6.w, ft6.w, ft1.z	\n"; //
			
			// pass 1: x0+r, y0+r
			// sample depth to ft4.z at the shifted pos
			code += "mov ft3, v0 					\n" + // (x0,y0)
					"add ft3.xy, ft3.xy, fc0.x	 	\n"; // (x0+r,y0+r)
			code += "tex ft0, ft3, fs1 <2d, nearest, repeat>	\n"; // sample depth map at shifted pos
			code += "dp4 ft4.z, ft0, fc3 	\n"; // (z1 = ft4.z)
			code += "sub ft4.z, ft4.z, fc1.z   \n" +
					"div ft4.z, fc1.w, ft4.z   \n" +
					"div ft4.z, ft4.z, fc2.x   \n" +
					"abs ft4.z, ft4.z     \n" +
					"sat ft4.z, ft4.z     \n" +
					"sub ft4.z, fc3.x, ft4.z   \n";
			//  z0tz = float3(dx - 0.0, dy - 0.0, tz - z0); // a vector from a central point to the probe (z0tz)
			code += "mov ft5, fc6.xxxx				\n" + // zeros
					"sub ft5.z, ft4.z, ft1.z		\n"	+ // (*).z = z1 - z0
					"add ft5.xy, ft5.xy, fc0.x		\n" + // (*).x = (*).y = 0 + r
					"nrm ft5.xyz, ft5.xyz			\n" +
					"dp3 ft5.w, ft5.xyz, fc6.xyz	\n";  // z0z1 * N
			code += "sub ft5.w, fc4.x, ft5.w		\n"; // invert
			code += "add ft6.w, ft6.w, ft5.w		\n"; //	ft6.w = accumulate a result of the pass1
			
			// pass 2: x0+r, y0-r
			code += "mov ft3, v0 					\n" + // (x0,y0)
					"add ft3.x, ft3.x, fc0.x	 	\n" + // (x0+r)
					"sub ft3.y, ft3.y, fc0.x	 	\n";  // (y0-r)
			code += "tex ft0, ft3, fs1 <2d, nearest, repeat>	\n"; // sample depth map at shifted pos
			code += "dp4 ft4.z, ft0, fc3		\n"; // (z1 = ft4.z)
			code += "sub ft4.z, ft4.z, fc1.z	\n" +
					"div ft4.z, fc1.w, ft4.z 	\n" +
					"div ft4.z, ft4.z, fc2.x	\n" +
					"abs ft4.z, ft4.z			\n" +
					"sat ft4.z, ft4.z			\n" +
					"sub ft4.z, fc3.x, ft4.z	\n";
			code += "mov ft5, fc6.xxxx				\n" + // zeros
					"sub ft5.z, ft4.z, ft1.z		\n"	+ // (*).z = z1 - z0
					"add ft5.x, ft5.x, fc0.x		\n" + // (*).x = 0 + r
					"sub ft5.y, ft5.y, fc0.y		\n" + // (*).y = 0 - r
					"nrm ft5.xyz, ft5.xyz			\n" +
					"dp3 ft5.w, ft5.xyz, fc6.xyz	\n"; // z0z1 * N
			code += "sub ft5.w, fc4.x, ft5.w		\n"; // invert
			code += "add ft6.w, ft6.w, ft5.w	\n";
			
			// pass 3: x0-r, y0+r
			code += "mov ft3, v0 					\n" + // (x0,y0)
					"sub ft3.x, ft3.x, fc0.x	 	\n" + // (x0-r)
					"add ft3.y, ft3.y, fc0.x	 	\n";  // (y0+r)
			code += "tex ft0, ft3, fs1 <2d, nearest, repeat>	\n"; // sample depth map at shifted pos
			code += "dp4 ft4.z, ft0, fc3 	\n"; // (z1 = ft4.z)
			code += "sub ft4.z, ft4.z, fc1.z   \n" +
					"div ft4.z, fc1.w, ft4.z   \n" +
					"div ft4.z, ft4.z, fc2.x   \n" +
					"abs ft4.z, ft4.z     \n" +
					"sat ft4.z, ft4.z     \n" +
					"sub ft4.z, fc3.x, ft4.z   \n";
			code += "mov ft5, fc6.xxxx				\n" + // zeros
					"sub ft5.z, ft4.z, ft1.z		\n"	+ // (*).z = z1 - z0
					"sub ft5.x, ft5.x, fc0.x		\n" + // (*).x = 0 - r
					"add ft5.y, ft5.y, fc0.y		\n" + // (*).y = 0 + r
					"nrm ft5.xyz, ft5.xyz			\n" +
					"dp3 ft5.w, ft5.xyz, fc6.xyz	\n"; // z0z1 * N
			code += "sub ft5.w, fc4.x, ft5.w		\n"; // invert
			code += "add ft6.w, ft6.w, ft5.w	\n";
			
			// pass 4: x0-r, y0-r
			code += "mov ft3, v0 					\n" + // (x0,y0)
					"sub ft3.xy, ft3.xy, fc0.x	 	\n"; // (x0-r,y0-r)
			code += "tex ft0, ft3, fs1 <2d, nearest, repeat>	\n"; // sample depth map at shifted pos
			code += "dp4 ft4.z, ft0, fc3 	\n"; // (z1 = ft4.z)
			code += "sub ft4.z, ft4.z, fc1.z   \n" +
					"div ft4.z, fc1.w, ft4.z   \n" +
					"div ft4.z, ft4.z, fc2.x   \n" +
					"abs ft4.z, ft4.z     \n" +
					"sat ft4.z, ft4.z     \n" +
					"sub ft4.z, fc3.x, ft4.z   \n";
			code += "mov ft5, fc6.xxxx				\n" + // zeros
					"sub ft5.z, ft4.z, ft1.z		\n"	+ // (*) = z1 - z0
					"sub ft5.xy, ft5.xy, fc0.x		\n" + // (*).x = (*).y = 0 - r
					"nrm ft5.xyz, ft5.xyz			\n" +
					"dp3 ft5.w, ft5.xyz, fc6.xyz	\n"; // z0z1 * N
			code += "sub ft5.w, fc4.x, ft5.w		\n"; // invert
			code += "add ft6.w, ft6.w, ft5.w			\n";
			
			// pass 5: x0, y0+r
			// sample depth to ft4.z at the shifted pos
			code += "mov ft3, v0 					\n" + // (x0,y0)
					"add ft3.y, ft3.y, fc0.x	 	\n"; // (y0+r)
			code += "tex ft0, ft3, fs1 <2d, nearest, repeat>	\n"; // sample depth map at shifted pos
			code += "dp4 ft4.z, ft0, fc3 	\n"; // (z1 = ft4.z)
			code += "sub ft4.z, ft4.z, fc1.z   \n" +
					"div ft4.z, fc1.w, ft4.z   \n" +
					"div ft4.z, ft4.z, fc2.x   \n" +
					"abs ft4.z, ft4.z     \n" +
					"sat ft4.z, ft4.z     \n" +
					"sub ft4.z, fc3.x, ft4.z   \n";
			//  z0tz = float3(dx - 0.0, dy - 0.0, tz - z0); // a vector from a central point to the probe (z0tz)
			code += "mov ft5, fc6.xxxx				\n" + // zeros
					"sub ft5.z, ft4.z, ft1.z		\n"	+ // (*).z = z1 - z0
					"add ft5.y, ft5.xy, fc0.x		\n" + // (*).y = 0 + r
					"nrm ft5.xyz, ft5.xyz			\n" +
					"dp3 ft5.w, ft5.xyz, fc6.xyz	\n";  // z0z1 * N
			code += "sub ft5.w, fc4.x, ft5.w		\n"; // invert
			code += "add ft6.w, ft6.w, ft5.w		\n"; //	ft6.w = accumulate a result of the pass1
			
			// pass 6: x0, y0-r
			code += "mov ft3, v0 					\n" + // (x0,y0)
					"sub ft3.y, ft3.y, fc0.x	 	\n";  // (y0-r)
			code += "tex ft0, ft3, fs1 <2d, nearest, repeat>	\n"; // sample depth map at shifted pos
			code += "dp4 ft4.z, ft0, fc3 	\n"; // (z1 = ft4.z)
			code += "sub ft4.z, ft4.z, fc1.z   \n" +
					"div ft4.z, fc1.w, ft4.z   \n" +
					"div ft4.z, ft4.z, fc2.x   \n" +
					"abs ft4.z, ft4.z     \n" +
					"sat ft4.z, ft4.z     \n" +
					"sub ft4.z, fc3.x, ft4.z   \n";
			code += "mov ft5, fc6.xxxx				\n" + // zeros
					"sub ft5.z, ft4.z, ft1.z		\n"	+ // (*).z = z1 - z0
					"sub ft5.y, ft5.y, fc0.y		\n" + // (*).y = 0 - r
					"nrm ft5.xyz, ft5.xyz			\n" +
					"dp3 ft5.w, ft5.xyz, fc6.xyz	\n"; // z0z1 * N
			code += "sub ft5.w, fc4.x, ft5.w		\n"; // invert
			code += "add ft6.w, ft6.w, ft5.w	\n";
			
			// pass 7: x0-r, y0
			code += "mov ft3, v0 					\n" + // (x0,y0)
					"sub ft3.x, ft3.x, fc0.x	 	\n"; // (x0-r)
			code += "tex ft0, ft3, fs1 <2d, nearest, repeat>	\n"; // sample depth map at shifted pos
			code += "dp4 ft4.z, ft0, fc3 	\n"; // (z1 = ft4.z)
			code += "sub ft4.z, ft4.z, fc1.z   \n" +
					"div ft4.z, fc1.w, ft4.z   \n" +
					"div ft4.z, ft4.z, fc2.x   \n" +
					"abs ft4.z, ft4.z     \n" +
					"sat ft4.z, ft4.z     \n" +
					"sub ft4.z, fc3.x, ft4.z   \n";
			code += "mov ft5, fc6.xxxx				\n" + // zeros
					"sub ft5.z, ft4.z, ft1.z		\n"	+ // (*).z = z1 - z0
					"sub ft5.x, ft5.x, fc0.x		\n" + // (*).x = 0 - r
					"nrm ft5.xyz, ft5.xyz			\n" +
					"dp3 ft5.w, ft5.xyz, fc6.xyz	\n"; // z0z1 * N
			code += "sub ft5.w, fc4.x, ft5.w		\n"; // invert
			code += "add ft6.w, ft6.w, ft5.w	\n";
			
			// pass 8: x0+r, y0
			code += "mov ft3, v0 					\n" + // (x0,y0)
					"add ft3.x, ft3.x, fc0.x	 	\n"; // (x0+r)
			code += "tex ft0, ft3, fs1 <2d, nearest, repeat>	\n"; // sample depth map at shifted pos
			code += "dp4 ft4.z, ft0, fc3 	\n"; // (z1 = ft4.z)
			code += "sub ft4.z, ft4.z, fc1.z   \n" +
					"div ft4.z, fc1.w, ft4.z   \n" +
					"div ft4.z, ft4.z, fc2.x   \n" +
					"abs ft4.z, ft4.z     \n" +
					"sat ft4.z, ft4.z     \n" +
					"sub ft4.z, fc3.x, ft4.z   \n";
			code += "mov ft5, fc6.xxxx				\n" + // zeros
					"sub ft5.z, ft4.z, ft1.z		\n"	+ // (*).z = z1 - z0
					"add ft5.x, ft5.x, fc0.x		\n" + // (*).x = 0 + r
					"nrm ft5.xyz, ft5.xyz			\n" +
					"dp3 ft5.w, ft5.xyz, fc6.xyz	\n"; // z0z1 * N
			code += "sub ft5.w, fc4.x, ft5.w		\n"; // invert
			code += "add ft6.w, ft6.w, ft5.w	\n";
			
			// ave
			code += "mul ft6.w, ft6.w, fc0.y	\n"; //*/
			
			// contrast
			code += "pow ft6.w, ft6.w, fc5.x	\n";
			
			// not greater than 1
			code += "sat ft6.w, ft6.w			\n";
			
			code += "tex ft2, v0, fs0 <2d,linear,clamp>	\n"; // sample view: rgb (ft2)
			switch (_blending) {
				case 0:
					// filter + image
					code += "mul ft2.xyz, ft6.w, ft2.xyz  \n"; // rgb = depth * rgb
					break;
				case 1:
					// filter only
					code += "mul ft2.xyz, ft6.w, fc4.xyz  \n"; // rgb = depth * color
					break;
				case 2:
					// image only
					break;
			}
			code += "mov oc, ft2	\n"; // return oc
			
			return code;
		}

		public function get range():Number {
			return _range;
		}

		public function set range(value:Number):void {
			_range = value;
			_data[8] = value; // fc2.x
		}

		public function get contrast():Number {
			return _contrast;
		}

		public function set contrast(value:Number):void {
			_data[20] = _contrast = value; // fc5.x = _data[20]
		}
		
		public function get r():Number {
			return _r;
		}

		public function set r(value:Number):void {
			_r = value;
			_data[0] = value; // fc0.x
		}
		
		public function toggleBlending():void {
			_blending++;
			if (_blending > 2) {
				_blending = 0;
			}
			invalidateProgram3D(); // coz _blending is'n a part of _data, we have to invalidateProgram to make changes in a getFragmentCode
		}
		
		override public function activate(stage3DProxy : Stage3DProxy, camera : Camera3D, depthTexture : Texture) : void
		{
			var context : Context3D = stage3DProxy._context3D;
			var n : Number = camera.lens.near;
			var f : Number = camera.lens.far;

			_data[3] = n; // fc0.w
			//_data[8] = f; // fc2.x
			_data[6] = f / (f - n); // fc1.z
			_data[7] = -n * _data[6]; // fc1.w

			context.setTextureAt(1, depthTexture);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 7);
		}

		override public function deactivate(stage3DProxy : Stage3DProxy) : void
		{
			stage3DProxy._context3D.setTextureAt(1, null);
		}

		override protected function updateTextures(stage : Stage3DProxy) : void
		{
			super.updateTextures(stage);
		}
	}
}
