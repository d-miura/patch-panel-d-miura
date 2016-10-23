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
        logger.info 'Duplicated patch is designated.'
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

  def create_mirror(dpid, port_monitor, port_mirror)
    @mirror[dpid].each do |p0, p1|
      if(p1 ==  port_mirror)
        logger.info "Port#{port_mirror} is alerady used as mirror."
        return
      end
    end

    @patch[dpid].each do |p0,p1|
      if(p0 == port_mirror or p1 == port_mirror)
        logger.info "Port#{port_mirror} is alerady used as patch."
        return
      end
    end

    port_patched = nil
    @patch[dpid].each do |p0,p1|
      port_patched = p0 if (p1 == port_monitor)
      port_patched = p1 if (p0 == port_monitor)
    end

    if port_patched == nil
      logger.info "Port#{port_monitor} is not patched."
      return
    end

    add_mirror_entries(dpid, port_monitor, port_mirror, port_patched)
    @mirror[dpid] << [port_monitor, port_mirror]
  end


  def list(dpid)
    logger.info "--------------------------------------------------"
    logger.info "list of patch \(dpid = #{dpid.to_hex}\)"
    @patch[dpid].each do |p0,p1|
      logger.info "#{p0} <---> #{p1}"
    end

    logger.info "list of mirror \(dpid = #{dpid.to_hex}\)"
    @mirror[dpid].each do |p0,p1|
      logger.info "#{p0} ----> #{p1}(mirror)"
    end
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

  def add_mirror_entries(dpid, port_monitor, port_mirror, port_monitor_patched)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_monitor),
                      actions: [
                        SendOutPort.new(port_monitor_patched),
                        SendOutPort.new(port_mirror),
                      ])
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_monitor_patched),
                      actions: [
                        SendOutPort.new(port_monitor),
                        SendOutPort.new(port_mirror),
                      ])
  end
end
