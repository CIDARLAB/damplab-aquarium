AQ.Wire.make = function(specs) {

  var wire = AQ.Wire.record(specs);

  if ( wire.from ) {
    wire.from.num_wires++;
  }
  if ( wire.to ) {
    wire.to.num_wires++;
  }

  return wire;

}

AQ.Wire.record_methods.disconnect = function() {

  var wire = this;

  if ( wire.from ) {
    wire.from.num_wires--;
    delete wire.from;
    delete wire.from_op;
  }
  if ( wire.to ) {
    wire.to.num_wires--;
    delete wire.to;
    delete wire.to_op;
  }
  
  return wire;  

}

AQ.Wire.record_getters.x0 = function() {
  return this.from_op.x + this.from_op.width/2 + (this.from.index - this.from_op.num_outputs/2.0 + 0.5)*this.snap;
}

AQ.Wire.record_getters.y0 = function() {
  return this.from_op.y;
}

AQ.Wire.record_getters.x1 = function() {
  return this.to_op.x + this.to_op.width/2 + (this.to.index - this.to_op.num_inputs/2.0 + 0.5)*this.snap
}

AQ.Wire.record_getters.y1 = function() {
  return this.to_op.y + this.to_op.height
}

AQ.Wire.record_getters.ymid = function() { 
  if ( !this.ymid_frac ) { this.ymid_frac = 0.5; }
  return this.ymid_frac*(this.y0 + this.y1);
}


AQ.Wire.record_getters.xmid = function() { 
  if ( !this.xmid_frac ) { this.xmid_frac = 0.5; }
  return this.xmid_frac*(this.x0 + this.x1);
}

AQ.Wire.record_getters.yint0 = function() { 
  return this.y0 - this.snap;
};       

AQ.Wire.record_getters.yint1 = function() { 
  return this.y1 + this.snap;
};           

AQ.Wire.record_getters.path = function() {

  if ( this.y0 >= this.y1 + 2 * this.snap ) {

    return ""   + this.x0 + "," + this.y0 + 
           " "  + this.x0 + "," + this.ymid + 
           " "  + this.x1 + "," + this.ymid +    
           " "  + this.x1 + "," + this.y1;

  } else {

    return ""   + this.x0   + "," + this.y0 + 
           " "  + this.x0   + " " + this.yint0 +           
           " "  + this.xmid + "," + this.yint0 + 
           " "  + this.xmid + "," + this.yint1 +   
           " "  + this.x1   + "," + this.yint1 +                 
           " "  + this.x1   + "," + this.y1;          

   }

}

AQ.Wire.record_getters.arrowhead = function() {

  return "M "  + this.x1 + " " + (this.y1 + 5) + 
         " L " + (this.x1 + 0.25*this.snap) + " " + (this.y1 + 0.75*this.snap) + 
         " L " + (this.x1 - 0.25*this.snap) + " " + (this.y1 + 0.75*this.snap) + " Z";

}