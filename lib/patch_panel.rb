# Software patch-panel.
class PatchPanel < Trema::Controller
  def start(_args)
    @patch = Hash.new { |hash, key| hash[key] = [] }
    @mirror = Hash.new { |hash, key| hash[key] = [] }
    logger.info 'PatchPanel started.'
  end

  def switch_ready(dpid)
    @patch[dpid].each do |port_a, port_b|
      delete_flow_entries dpid, port_a, port_b
      add_flow_entries dpid, port_a, port_b
    end
  end

  def create_patch(dpid, port_a, port_b)
    @patch[dpid].each do |ports|
      if(ports.include?(port_a) or ports.include?(port_b))
        logger.info 'Duplicated port is designated.'
        return
      end
    end
    add_flow_entries dpid, port_a, port_b
    @patch[dpid] << [port_a, port_b].sort
  end

  def delete_patch(dpid, port_a, port_b)
    @patch[dpid].each do |ports|
      if(ports.include?(port_a) and ports.include?(port_b))
        delete_flow_entries dpid, port_a, port_b
        @patch[dpid].delete([port_a, port_b].sort)
        return
      end
    end

    logger.info 'Designated patch is not exist.'
  end

  private

  def add_flow_entries(dpid, port_a, port_b)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: SendOutPort.new(port_b))
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_b),
                      actions: SendOutPort.new(port_a))
  end

  def delete_flow_entries(dpid, port_a, port_b)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_b))
  end
end
