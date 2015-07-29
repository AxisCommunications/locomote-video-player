package com.axis.rtspclient {
    import com.axis.Logger;
    import com.axis.rtspclient.ByteArrayUtils;
    import com.axis.rtspclient.RTP

    import flash.utils.ByteArray;

    public class RTPSource {

        private static const RTP_SEQ_MOD:uint = 1 << 16;
        private static const MAX_DROPOUT:uint = 3000;
        private static const MAX_MISORDER:uint = 100;
        private static const MIN_SEQUENTIAL:uint = 2;

        public var ssrc:uint = 0;
//
//        private var baseExtSeqNumReceived:uint = 0;
//        private var highestExtSeqNumReceived:uint = 0;
//        private var haveInitialSequenceNumber:bool = false;
//
//        private var previousPacketRTPTimestamp:uint = 0;
//
//        private var lastReceivedSR_NTP_msw:uint = 0;
//        private var lastReceivedSR_NTP_lsw:uint = 0;
//        private var maxInterPacketGap:uint = 0;
//        private var minInterPacketGap:uint = 0;
//
//        private var lastReceivedSR_time:Date;
//        private var lastPacketReceptionTime:Date;
//
//        private var totalBytesReceivedHigh:uint = 0;
//        private var totalBytesReceivedLow:uint = 0;

        public var max_seq:uint = 0;
        public var cycles:uint = 0;
        public var jitter:Number = 0.0;

        private var base_seq:uint = 0;

        private var bad_seq:uint = 0;

        private var received:uint = 0;
        private var received_prior:uint = 0;
        private var expected_prior:uint = 0;

        private var probation:uint = 0;

        private var prevTransit:int = ~0;

        private var totalTime:Number = 0;
        private var startTime:Date = null;

        private var clock:uint = 0;

        public function RTPSource(rtppkt:RTP, sdp:SDP) {
            ssrc = rtppkt.ssrc;
            initSequence(rtppkt.sequence);
            max_seq = rtppkt.sequence - 1;
            probation = MIN_SEQUENTIAL;
            clock = sdp.getMediaBlockByPayloadType(rtppkt.pt).rtpmap[rtppkt.pt].clock;
        }

//        public function recordIncomingPacket(packet:RTP) {
//            totalPacketsReceived++;
//            packetsReceivedSinceLastReport++;
//
//            if (!haveInitialSequenceNumber) {
//                baseExtSeqNumReceived = 0x10000 | sequenceNumber;
//                highestExtSeqNumReceived = 0x10000 | sequenceNumber;
//                haveInitialSequenceNumber = true;
//            }
//
//            var temp = totalBytesReceivedLow;
//            totalBytesReceivedLow += packet.dataSize();
//            if (temp > totalBytesReceivedLow)
//                totalBytesReceivedHigh++
//
//            var oldSeqNum:uint = highestExtSeqNumReceived & 0x0000FFFF;
//            var seqNumCycle:uint = highestExtSeqNumReceived & 0xFFFF0000;
//            var seqNumDifference:uint = uint(int(packet.sequence) - int(oldSeqNum));
//
//            var expected:uint = highestExtSeqNumReceived - baseExtSeqNumReceived + 1;
//
//            var newSeqNum = 0;
//            if (seqNumLT(oldSeqNum, seqNum)) {
//              if (seqNumDifference >= 0x8000) {
//                  seqNumCycle += 0x10000;
//              }
//
//              newSeqNum = seqNumCycle|seqNum;
//              if (newSeqNum > highestExtSeqNumReceived) {
//                  highestExtSeqNumReceived = newSeqNum;
//              }
//            } else if (totalNumPacketsReceived > 1) {
//                if ((int)seqNumDifference >= 0x8000) {
//                    seqNumCycle -= 0x10000;
//                }
//
//                newSeqNum = seqNumCycle|seqNum;
//                if (newSeqNum < baseExtSeqNumReceived) {
//                    baseExtSeqNumReceived = newSeqNum;
//                }
//            }
//
//            var timeNow:Date = new Date();
//            if (lastPacketReceptionTime.UTC != 0) {
//                var gap:uint = timeNow.UTC - lastPacketReceptionTime.UTC;
//                if (gap > maxInterPacketGap)
//                    maxInterPacketGap = gap;
//                if (gap < minInterPacketGap)
//                    minInterPacketGap = gap;
//                totalInterPacketGaps += gap;
//            }
//            lastPacketReceptionTime = timeNow;
//        }
//
//        public resetCounters() {
//            packetsReceivedSinceLastReport = 0;
//            haveInitialSequenceNumber = false;
//        }

//        private function seqNumLT(val1:uint, val2:uint):Boolean {
//            var diff:int = val2-val1;
//            if (diff > 0) {
//                return (diff < 0x8000);
//            } else if (diff < 0) {
//                return (diff < -0x8000);
//            } else {
//                return false;
//            }
//        }

        public function initSequence(seq:uint):void {
            base_seq = seq;
            max_seq = seq;
            bad_seq = RTP_SEQ_MOD + 1;
            cycles = 0;
            received = 0;
            received_prior = 0;
            expected_prior = 0;
        }

        public function updateSequence(senderSsrc:uint, seq:uint):Boolean {
            var udelta:uint = seq - max_seq;

            if (senderSsrc != ssrc) {
                initSequence(seq);
                max_seq = seq - 1;
                probation = MIN_SEQUENTIAL;
                return false;
            }
            if (probation) {
                /* packet is in sequence */
                if (seq == max_seq + 1) {
                    probation--;
                    max_seq = seq;
                    if (probation == 0) {
                        initSequence(seq);
                        received++;
                        return true;
                    }
                } else {
                    probation = MIN_SEQUENTIAL - 1;
                    max_seq = seq;
                }
                return false;
            } else if (udelta < MAX_DROPOUT) {
                /* in order, with permissible gap */
                if (seq < max_seq) {
                    /* Sequence number wrapped - count another 64k cycle. */
                    cycles += RTP_SEQ_MOD;
                    Logger.log("Increment cycles: " + cycles)
                }
                max_seq = seq;
            } else if (udelta <= RTP_SEQ_MOD - MAX_MISORDER) {
                /* the sequence number made a very large jump */
                if (seq == bad_seq) {
                    initSequence(seq);
                } else {
                    bad_seq = (seq + 1) & (RTP_SEQ_MOD-1);
                    return false;
                }
            } else {
                /* duplicate or reordered packet */
            }
            received++;
            return true;
        }

        public function recordIncomingPkt(rtppkt:RTP, timeReceived:Date):void {
            updateSequence(rtppkt.ssrc, rtppkt.sequence);
            updateJitter(rtppkt, timeReceived)
        }

        public function getFractionLost():Object {
            var extended_max:uint = cycles + max_seq;
            var expected:uint = extended_max - base_seq + 1;

            var lost:int = expected - received;

            var expected_interval:uint = expected - expected_prior;
            expected_prior = expected;
            var received_interval:uint = received - received_prior;
            received_prior = received;
            var lost_interval:uint = expected_interval = received_interval;
            var fraction:uint = 0;

            if (expected_interval != 0 && lost_interval != 0)
                fraction = (lost_interval << 8) / expected_interval;
            return {fraction: fraction, lost: lost};
        }

        public function updateJitter(rtppkt:RTP, receivedTime:Date):void {


            var arrivalTimestamp:uint = (receivedTime.time * clock / 1000);
            var temp:Number = ((2.0*clock*receivedTime.millisecondsUTC + 1000.0)/2000);
            arrivalTimestamp += temp// note: rounding

//                if (clock == 8000)
//                    Logger.log("****** QWER updateJitter - rtpTimestamp: " + rtppkt.timestamp + "   receivedTime.time: " + receivedTime.time + " arrivalTimestamp: " + arrivalTimestamp)
            var transit:int = arrivalTimestamp - rtppkt.timestamp;
            if (prevTransit == ~0)
                prevTransit = transit;
            var d:int = transit - prevTransit;
            // Ignore pkt in jitter calculations if it has same timestamp as previous packet.
            if (d != 0) {
                if (d < 0) d = -d;
                jitter += (1.0 / 16.0) * (d - jitter);
//                if (clock == 8000) {
//                    Logger.log("****** QWER updateJitter - jitter: " + jitter + " d: " + d + " transit: " + transit + "   prev: " + prevTransit )
//                }
                prevTransit = transit;
            }
        }
    }
}
