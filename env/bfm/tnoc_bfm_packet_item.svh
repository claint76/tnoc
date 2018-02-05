`ifndef TNOC_BFM_PACKET_ITEM_SVH
`define TNOC_BFM_PACKET_ITEM_SVH
typedef tue_sequence_item #(
  tnoc_bfm_configuration, tnoc_bfm_status
) tnoc_bfm_packet_item_base;

class tnoc_bfm_packet_item extends tnoc_bfm_packet_item_base;
  rand  tnoc_bfm_packet_type      packet_type;
  rand  tnoc_bfm_location_id      destination_id;
  rand  tnoc_bfm_location_id      source_id;
  rand  tnoc_bfm_vc               virtual_channel;
  rand  tnoc_bfm_tag              tag;
  rand  int                       length;
  rand  tnoc_bfm_routing_mode     routing_mode;
  rand  bit                       invalid_destination;
  rand  tnoc_bfm_burst_type       burst_type;
  rand  int                       burst_length;
  rand  int                       burst_size;
  rand  tnoc_bfm_address          address;
  rand  tnoc_bfm_response_status  status;
  rand  tnoc_bfm_data             data[];
  rand  tnoc_bfm_byte_enable      byte_enable[];

        int                       tr_handle;

  static  uvm_packer  flit_packer;

  constraint c_default_source_id {
    soft source_id.x == configuration.id_x;
    soft source_id.y == configuration.id_y;
  }

  constraint c_valid_virtual_channel {
    solve packet_type before virtual_channel;
    virtual_channel < configuration.virtual_channels;
  }

  constraint c_default_virtual_channel {
    if (packet_type inside {TNOC_BFM_RESPONSE, TNOC_BFM_RESPONSE_WITH_DATA}) {
      soft virtual_channel == 0;
    }
    else {
      soft virtual_channel == 1;
    }
  }

  constraint c_valid_tag {
    tag < 2**configuration.tag_width;
  }

  constraint c_default_invalid_destination {
    soft invalid_destination == 0;
  }

  constraint c_default_burst_type {
    solve packet_type before burst_type;
    if (packet_type[7]) {
      burst_type == TNOC_BFM_FIXED_BURST;
    }
  }

  constraint c_valid_burst_length {
    solve packet_type before burst_length;
    if ((!packet_type[7]) || packet_type[6]) {
      burst_length inside {[1:2**configuration.burst_length_width]};
    }
    else {
      burst_length == 0;
    }
  }

  constraint c_valid_burst_size {
    solve packet_type before burst_size;
    if (!packet_type[7]) {
      burst_size inside {[1:configuration.data_width / 8]};
      $countones(burst_size) == 1;
    }
    else {
      burst_size == 0;
    }
  }

  constraint c_default_address {
    solve packet_type before address;
    if (packet_type[7]) {
      address == 0;
    }
  }

  constraint c_valid_status {
    solve packet_type before status;
    if (!packet_type[7]) {
      status == TNOC_BFM_OKAY;
    }
  }

  constraint c_defualt_status {
    if (packet_type[7]) {
      soft status == TNOC_BFM_OKAY;
    }
  }

  constraint c_valid_data {
    solve packet_type, burst_length before data;
    if (packet_type[6]) {
      data.size == burst_length;
      foreach (data[i]) {
        (data[i] >> configuration.data_width) == 0;
      }
    }
    else {
      data.size == 0;
    }
  }

  constraint c_valid_byte_enable {
    solve packet_type, burst_length before byte_enable;
    if ((!packet_type[7]) && packet_type[6]) {
      byte_enable.size == burst_length;
      foreach (byte_enable[i]) {
        (byte_enable[i] >> configuration.byte_enable_width) == 0;
      }
    }
    else {
      byte_enable.size == 0;
    }
  }

  function void post_randomize();
    if (is_response()) begin
      burst_length  = 0;
    end
  endfunction

  function bit is_request;
    return (!packet_type[7]) ? '1 : '0;
  endfunction

  function bit is_response;
    return (packet_type[7]) ? '1 : '0;
  endfunction

  function bit has_payload();
    return (packet_type[6]) ? '1 : '0;
  endfunction

  function void pack_flits(ref tnoc_bfm_flit flits[$]);
    get_header_flits(flits);
    get_payload_flits(flits);
  endfunction

  function void pack_flit_items(ref tnoc_bfm_flit_item flit_items[$]);
    tnoc_bfm_flit flits[$];
    pack_flits(flits);
    foreach (flits[i]) begin
      tnoc_bfm_flit_item  flit_item;
      flit_item = tnoc_bfm_flit_item::type_id::create($sformatf("flit_item[%0d]", i));
      flit_item.unpack_flit(flits[i]);
      flit_items.push_back(flit_item);
    end
  endfunction

  function void unpack_flits(const ref tnoc_bfm_flit flits[$]);
    unpack_header_flits(flits);

    if (!has_payload()) begin
      return;
    end

    unpack_payload_flits(flits);
  endfunction

  function void unpack_flit_items(const ref tnoc_bfm_flit_item flit_items[$]);
    tnoc_bfm_flit flits[$];
    foreach (flit_items[i]) begin
      flits.push_back(flit_items[i].get_flit());
    end
    unpack_flits(flits);
  endfunction

  local function void get_header_flits(ref tnoc_bfm_flit flits[$]);
    uvm_packer  packer;
    int         header_width;

    packer  = get_flit_packer();
    packer.pack_field_int(packet_type        , $bits(tnoc_bfm_packet_type) );
    packer.pack_field_int(destination_id.y   , configuration.id_y_width    );
    packer.pack_field_int(destination_id.x   , configuration.id_x_width    );
    packer.pack_field_int(source_id.y        , configuration.id_y_width    );
    packer.pack_field_int(source_id.x        , configuration.id_x_width    );
    packer.pack_field_int(virtual_channel    , configuration.vc_width      );
    packer.pack_field_int(tag                , configuration.tag_width     );
    packer.pack_field_int(routing_mode       , $bits(tnoc_bfm_routing_mode));
    packer.pack_field_int(invalid_destination, 1                           );
    if (is_request()) begin
      packer.pack_field_int(burst_type        , $bits(tnoc_bfm_burst_type)      );
      packer.pack_field_int(burst_length      , configuration.burst_length_width);
      packer.pack_field_int($clog2(burst_size), configuration.burst_size_width  );
      packer.pack_field_int(address           , configuration.address_width     );
      header_width  = configuration.get_request_header_width();
    end
    else begin
      packer.pack_field_int(status, $bits(tnoc_bfm_response_status));
      header_width  = configuration.get_response_header_width();
    end
    packer.set_packed_size();

    while (header_width > 0) begin
      int           unpack_size;
      tnoc_bfm_flit flit;

      if (header_width > configuration.get_flit_width()) begin
        unpack_size = configuration.get_flit_width();
      end
      else begin
        unpack_size = header_width;
      end

      flit.flit_type  = TNOC_BFM_HEADER_FLIT;
      flit.data       = packer.unpack_field(unpack_size);
      flits.push_back(flit);

      header_width  -= unpack_size;
    end

    flits[0].head = 1;
    if (!packet_type[6]) begin
      flits[$].tail = 1;
    end
  endfunction

  local function void unpack_header_flits(const ref tnoc_bfm_flit flits[$]);
    uvm_packer    packer  = get_flit_packer();

    foreach (flits[i]) begin
      if (flits[i].flit_type == TNOC_BFM_PAYLOAD_FLIT) begin
        break;
      end
      packer.pack_field(flits[i].data, configuration.get_flit_width());
    end
    packer.set_packed_size();

    packet_type         = tnoc_bfm_packet_type'(packer.unpack_field_int($bits(tnoc_bfm_packet_type)));
    destination_id.y    = packer.unpack_field_int(configuration.id_y_width);
    destination_id.x    = packer.unpack_field_int(configuration.id_x_width);
    source_id.y         = packer.unpack_field_int(configuration.id_y_width);
    source_id.x         = packer.unpack_field_int(configuration.id_x_width);
    virtual_channel     = packer.unpack_field_int(configuration.vc_width);
    tag                 = packer.unpack_field_int(configuration.tag_width);
    routing_mode        = tnoc_bfm_routing_mode'(packer.unpack_field_int($bits(tnoc_bfm_routing_mode)));
    invalid_destination = packer.unpack_field_int(1);
    if (is_request()) begin
      burst_type    = tnoc_bfm_burst_type'(packer.unpack_field_int($bits(tnoc_bfm_burst_type)));
      burst_length  = packer.unpack_field_int(configuration.burst_length_width);
      burst_size    = 2**packer.unpack_field_int(configuration.burst_size_width);
      address       = packer.unpack_field_int(configuration.address_width);
    end
    else begin
      status  = tnoc_bfm_response_status'(packer.unpack_field_int($bits(tnoc_bfm_response_status)));
    end
  endfunction

  local function void get_payload_flits(ref tnoc_bfm_flit flits[$]);
    foreach (data[i]) begin
      uvm_packer    packer;
      tnoc_bfm_flit flit;

      packer  = get_flit_packer();
      packer.pack_field(data[i], configuration.data_width);
      if (is_request()) begin
        packer.pack_field_int(byte_enable[i], configuration.byte_enable_width);
      end
      else begin
        packer.pack_field_int('0, configuration.byte_enable_width);
      end
      packer.set_packed_size();

      flit.flit_type  = TNOC_BFM_PAYLOAD_FLIT;
      flit.data       = packer.unpack_field(configuration.get_payload_width());
      flits.push_back(flit);
    end

    flits[$].tail = 1;
  endfunction

  local function void unpack_payload_flits(const ref tnoc_bfm_flit flits[$]);
    tnoc_bfm_flit payload_flits[$];

    payload_flits = flits.find(flit) with (flit.flit_type == TNOC_BFM_PAYLOAD_FLIT);

    data  = new[payload_flits.size];
    if (is_request()) begin
      byte_enable = new[payload_flits.size];
    end

    foreach (data[i]) begin
      uvm_packer  packer;

      packer  = get_flit_packer();
      packer.pack_field(payload_flits[i].data, configuration.get_payload_width());
      packer.set_packed_size();

      data[i] = packer.unpack_field(configuration.data_width);
      if (is_request()) begin
        byte_enable[i]  = packer.unpack_field_int(configuration.byte_enable_width);
      end
    end
  endfunction

  local function uvm_packer get_flit_packer();
    if (flit_packer == null) begin
      flit_packer             = new();
      flit_packer.big_endian  = 0;
    end
    flit_packer.reset();
    return flit_packer;
  endfunction

  `tue_object_default_constructor(tnoc_bfm_packet_item)
  `uvm_object_utils_begin(tnoc_bfm_packet_item)
    `uvm_field_enum(tnoc_bfm_packet_type, packet_type, UVM_DEFAULT)
    `uvm_field_int(destination_id     , UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(source_id          , UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(virtual_channel    , UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(tag                , UVM_DEFAULT | UVM_HEX)
    `uvm_field_enum(tnoc_bfm_routing_mode   , routing_mode, UVM_DEFAULT)
    `uvm_field_int(invalid_destination, UVM_DEFAULT | UVM_BIN)
    `uvm_field_enum(tnoc_bfm_burst_type     , burst_type  , UVM_DEFAULT)
    `uvm_field_int(burst_length       , UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(burst_size         , UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(address            , UVM_DEFAULT | UVM_HEX)
    `uvm_field_enum(tnoc_bfm_response_status, status, UVM_DEFAULT)
    `uvm_field_array_int(data       , UVM_DEFAULT | UVM_HEX)
    `uvm_field_array_int(byte_enable, UVM_DEFAULT | UVM_HEX)
  `uvm_object_utils_end
endclass
`endif